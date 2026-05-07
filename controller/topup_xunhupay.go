package controller

import (
	"bytes"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/QuantumNous/new-api/common"
	"github.com/QuantumNous/new-api/logger"
	"github.com/QuantumNous/new-api/model"
	"github.com/QuantumNous/new-api/service"
	"github.com/QuantumNous/new-api/setting"
	"github.com/QuantumNous/new-api/setting/system_setting"
	"github.com/gin-gonic/gin"
)

// XunhupayCreateOrderResponse 虎皮椒创建订单响应
type XunhupayCreateOrderResponse struct {
	Errcode   int    `json:"errcode"`
	Errmsg    string `json:"errmsg"`
	UrlQrcode string `json:"url_qrcode"`
	Url       string `json:"url"`
	OrderID   string `json:"openid"` // 历史遗留，返回名是 openid，值是 orderid
	Hash      string `json:"hash"`
}

// buildXunhupayHash 按虎皮椒规则生成签名
// 1. 参数按 ASCII 码从小到大排序（字典序）
// 2. 值为空的参数不参与签名
// 3. hash 参数不参与签名
// 4. 用 key1=value1&key2=value2... 拼接
// 5. 最后直接拼接 appsecret，MD5 小写
func buildXunhupayHash(params map[string]string, appSecret string) string {
	var keys []string
	for k := range params {
		if k == "hash" {
			continue
		}
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var parts []string
	for _, k := range keys {
		v := params[k]
		if v == "" {
			continue
		}
		parts = append(parts, k+"="+v)
	}
	str := strings.Join(parts, "&") + appSecret
	return fmt.Sprintf("%x", md5.Sum([]byte(str)))
}

// RequestXunhupayPay 创建虎皮椒支付订单
func RequestXunhupayPay(c *gin.Context) {
	if !isXunhupayTopUpEnabled() {
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "虎皮椒支付未启用"})
		return
	}

	var req struct {
		Amount int64 `json:"amount"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "参数错误"})
		return
	}

	if req.Amount < int64(setting.XunhupayMinTopUp) {
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": fmt.Sprintf("充值数量不能小于 %d", setting.XunhupayMinTopUp)})
		return
	}

	id := c.GetInt("id")
	user, err := model.GetUserById(id, false)
	if err != nil || user == nil {
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "用户不存在"})
		return
	}

	// 生成唯一订单号
	tradeNo := fmt.Sprintf("XHP-%d-%d-%s", id, time.Now().UnixMilli(), randomString(8))

	// 创建本地订单
	topUp := &model.TopUp{
		UserId:          id,
		Amount:          req.Amount,
		Money:           float64(req.Amount),
		TradeNo:         tradeNo,
		PaymentMethod:   model.PaymentMethodXunhupay,
		PaymentProvider: model.PaymentProviderXunhupay,
		CreateTime:      time.Now().Unix(),
		Status:          common.TopUpStatusPending,
	}
	if err := topUp.Insert(); err != nil {
		logger.LogError(c.Request.Context(), fmt.Sprintf("虎皮椒创建充值订单失败 user_id=%d trade_no=%s error=%q", id, tradeNo, err.Error()))
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "创建订单失败"})
		return
	}

	// 构建虎皮椒请求参数
	gateway := strings.TrimRight(setting.XunhupayGateway, "/")
	if gateway == "" {
		gateway = "https://api.xunhupay.com"
	}

	callbackAddr := service.GetCallbackAddress()
	notifyUrl := callbackAddr + "/api/xunhupay/webhook"
	returnUrl := system_setting.ServerAddress + "/console/topup?show_history=true"

	nonceStr := randomString(16)
	now := strconv.FormatInt(time.Now().Unix(), 10)

	payData := map[string]string{
		"version":        "1.1",
		"appid":          setting.XunhupayAppId,
		"trade_order_id": tradeNo,
		"total_fee":      fmt.Sprintf("%.2f", float64(req.Amount)),
		"title":          fmt.Sprintf("充值 %d", req.Amount),
		"time":           now,
		"notify_url":     notifyUrl,
		"return_url":     returnUrl,
		"nonce_str":      nonceStr,
	}
	payData["hash"] = buildXunhupayHash(payData, setting.XunhupayAppSecret)

	// 发送 JSON POST 请求到虎皮椒
	apiURL := gateway + "/payment/do.html"
	jsonBody, _ := json.Marshal(payData)

	resp, err := http.Post(apiURL, "application/json", bytes.NewReader(jsonBody))
	if err != nil {
		logger.LogError(c.Request.Context(), fmt.Sprintf("虎皮椒请求失败 user_id=%d trade_no=%s error=%q", id, tradeNo, err.Error()))
		topUp.Status = common.TopUpStatusFailed
		_ = topUp.Update()
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "支付网关请求失败"})
		return
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		logger.LogError(c.Request.Context(), fmt.Sprintf("虎皮椒响应读取失败 user_id=%d trade_no=%s error=%q", id, tradeNo, err.Error()))
		topUp.Status = common.TopUpStatusFailed
		_ = topUp.Update()
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "支付网关响应异常"})
		return
	}

	var xhpResp XunhupayCreateOrderResponse
	if err := json.Unmarshal(bodyBytes, &xhpResp); err != nil {
		logger.LogError(c.Request.Context(), fmt.Sprintf("虎皮椒响应解析失败 user_id=%d trade_no=%s body=%s error=%q", id, tradeNo, string(bodyBytes), err.Error()))
		topUp.Status = common.TopUpStatusFailed
		_ = topUp.Update()
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": "支付网关响应格式错误"})
		return
	}

	if xhpResp.Errcode != 0 {
		logger.LogWarn(c.Request.Context(), fmt.Sprintf("虎皮椒创建订单业务失败 user_id=%d trade_no=%s errmsg=%s", id, tradeNo, xhpResp.Errmsg))
		topUp.Status = common.TopUpStatusFailed
		_ = topUp.Update()
		c.JSON(http.StatusOK, gin.H{"message": "error", "data": xhpResp.Errmsg})
		return
	}

	logger.LogInfo(c.Request.Context(), fmt.Sprintf("虎皮椒充值订单创建成功 user_id=%d trade_no=%s amount=%d", id, tradeNo, req.Amount))

	c.JSON(http.StatusOK, gin.H{
		"message": "success",
		"data": gin.H{
			"qr_url":    xhpResp.UrlQrcode,
			"pay_url":   xhpResp.Url,
			"order_id":  tradeNo,
			"amount":    req.Amount,
		},
	})
}

// XunhupayWebhook 处理虎皮椒异步通知
// 回调方式：POST form 类型
func XunhupayWebhook(c *gin.Context) {
	if !isXunhupayWebhookEnabled() {
		c.String(http.StatusForbidden, "fail")
		return
	}

	// 虎皮椒回调是 form 类型
	notifyData := map[string]string{
		"trade_order_id": c.PostForm("trade_order_id"),
		"total_fee":      c.PostForm("total_fee"),
		"transaction_id": c.PostForm("transaction_id"),
		"open_order_id":  c.PostForm("open_order_id"),
		"order_title":    c.PostForm("order_title"),
		"status":         c.PostForm("status"),
		"plugins":        c.PostForm("plugins"),
		"attach":         c.PostForm("attach"),
		"appid":          c.PostForm("appid"),
		"time":           c.PostForm("time"),
		"nonce_str":      c.PostForm("nonce_str"),
		"hash":           c.PostForm("hash"),
	}

	outTradeNo := notifyData["trade_order_id"]
	status := notifyData["status"]
	hash := notifyData["hash"]

	logger.LogInfo(c.Request.Context(), fmt.Sprintf("虎皮椒 webhook 收到请求 trade_order_id=%s status=%s client_ip=%s", outTradeNo, status, c.ClientIP()))

	if notifyData["appid"] != setting.XunhupayAppId {
		logger.LogWarn(c.Request.Context(), fmt.Sprintf("虎皮椒 webhook appid 不匹配 trade_order_id=%s", outTradeNo))
		c.String(http.StatusBadRequest, "fail")
		return
	}

	// 验证签名
	expectedHash := buildXunhupayHash(notifyData, setting.XunhupayAppSecret)
	if hash != expectedHash {
		logger.LogWarn(c.Request.Context(), fmt.Sprintf("虎皮椒 webhook 验签失败 trade_order_id=%s expected=%s got=%s", outTradeNo, expectedHash, hash))
		c.String(http.StatusBadRequest, "fail")
		return
	}

	// status = "OD" 表示已支付
	if status != "OD" {
		logger.LogInfo(c.Request.Context(), fmt.Sprintf("虎皮椒订单状态未成功，忽略 trade_order_id=%s status=%s", outTradeNo, status))
		c.String(http.StatusOK, "SUCCESS")
		return
	}

	LockOrder(outTradeNo)
	defer UnlockOrder(outTradeNo)

	if err := model.RechargeXunhupay(outTradeNo, c.ClientIP()); err != nil {
		logger.LogError(c.Request.Context(), fmt.Sprintf("虎皮椒充值处理失败 trade_order_id=%s error=%q", outTradeNo, err.Error()))
		c.String(http.StatusBadRequest, "fail")
		return
	}

	logger.LogInfo(c.Request.Context(), fmt.Sprintf("虎皮椒充值成功 trade_order_id=%s client_ip=%s", outTradeNo, c.ClientIP()))
	c.String(http.StatusOK, "SUCCESS")
}

// randomString 生成指定长度的随机字符串
func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}
