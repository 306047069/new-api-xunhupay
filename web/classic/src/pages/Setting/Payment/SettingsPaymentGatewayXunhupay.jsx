/*
Copyright (C) 2025 QuantumNous

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

For commercial licensing, please contact support@quantumnous.com
*/

import React, { useEffect, useState, useRef } from 'react';
import { Banner, Button, Form, Row, Col, Spin } from '@douyinfe/semi-ui';
import {
  API,
  removeTrailingSlash,
  showError,
  showSuccess,
} from '../../../helpers';
import { useTranslation } from 'react-i18next';
import { Info } from 'lucide-react';

const toBoolean = (value) => value === true || value === 'true';

export default function SettingsPaymentGatewayXunhupay(props) {
  const { t } = useTranslation();
  const sectionTitle = props.hideSectionTitle ? undefined : t('虎皮椒支付设置');
  const [loading, setLoading] = useState(false);
  const [inputs, setInputs] = useState({
    XunhupayEnabled: false,
    XunhupayAppId: '',
    XunhupayAppSecret: '',
    XunhupayGateway: '',
    XunhupayMinTopUp: 1,
  });
  const formApiRef = useRef(null);

  useEffect(() => {
    if (props.options && formApiRef.current) {
      const currentInputs = {
        XunhupayEnabled: toBoolean(props.options.XunhupayEnabled),
        XunhupayAppId: props.options.XunhupayAppId || '',
        XunhupayAppSecret: props.options.XunhupayAppSecret || '',
        XunhupayGateway: props.options.XunhupayGateway || '',
        XunhupayMinTopUp:
          props.options.XunhupayMinTopUp !== undefined
            ? parseFloat(props.options.XunhupayMinTopUp)
            : 1,
      };
      setInputs(currentInputs);
      formApiRef.current.setValues(currentInputs);
    }
  }, [props.options]);

  const handleFormChange = (values) => {
    setInputs(values);
  };

  const submitXunhupaySetting = async () => {
    if (props.options.ServerAddress === '') {
      showError(t('请先填写服务器地址'));
      return;
    }

    setLoading(true);
    try {
      const options = [
        {
          key: 'XunhupayEnabled',
          value: inputs.XunhupayEnabled ? 'true' : 'false',
        },
        {
          key: 'XunhupayAppId',
          value: inputs.XunhupayAppId || '',
        },
        {
          key: 'XunhupayGateway',
          value: inputs.XunhupayGateway || '',
        },
        {
          key: 'XunhupayMinTopUp',
          value: String(inputs.XunhupayMinTopUp || 1),
        },
      ];

      if (inputs.XunhupayAppSecret && inputs.XunhupayAppSecret !== '') {
        options.push({
          key: 'XunhupayAppSecret',
          value: inputs.XunhupayAppSecret,
        });
      }

      const requestQueue = options.map((opt) =>
        API.put('/api/option/', {
          key: opt.key,
          value: opt.value,
        }),
      );

      const results = await Promise.all(requestQueue);

      const errorResults = results.filter((res) => !res.data.success);
      if (errorResults.length > 0) {
        errorResults.forEach((res) => {
          showError(res.data.message);
        });
      } else {
        showSuccess(t('更新成功'));
        props.refresh && props.refresh();
      }
    } catch (error) {
      showError(t('更新失败'));
    }
    setLoading(false);
  };

  return (
    <Spin spinning={loading}>
      <Form
        initValues={inputs}
        onValueChange={handleFormChange}
        getFormApi={(api) => (formApiRef.current = api)}
      >
        <Form.Section text={sectionTitle}>
          <Banner
            type='info'
            icon={<Info size={16} />}
            description={
              <>
                请先在
                <a href='https://www.xunhupay.com' target='_blank' rel='noreferrer'>
                  虎皮椒支付平台
                </a>
                注册账号并创建应用，获取 AppID 和 AppSecret。
                <br />
                {t('回调地址')}：
                {props.options.ServerAddress
                  ? removeTrailingSlash(props.options.ServerAddress)
                  : t('网站地址')}
                /api/xunhupay/webhook
              </>
            }
            style={{ marginBottom: 16 }}
          />

          <Row gutter={{ xs: 8, sm: 16, md: 24, lg: 24, xl: 24, xxl: 24 }}>
            <Col xs={24} sm={24} md={8} lg={8} xl={8}>
              <Form.Switch
                field='XunhupayEnabled'
                label={t('启用虎皮椒支付')}
                size='default'
                checkedText='｜'
                uncheckedText='〇'
              />
            </Col>
            <Col xs={24} sm={24} md={8} lg={8} xl={8}>
              <Form.Input
                field='XunhupayAppId'
                label={t('AppID')}
                placeholder='10001'
              />
            </Col>
            <Col xs={24} sm={24} md={8} lg={8} xl={8}>
              <Form.Input
                field='XunhupayAppSecret'
                label={t('App Secret')}
                placeholder={t('敏感信息不会发送到前端显示')}
                type='password'
              />
            </Col>
          </Row>

          <Row
            gutter={{ xs: 8, sm: 16, md: 24, lg: 24, xl: 24, xxl: 24 }}
            style={{ marginTop: 16 }}
          >
            <Col xs={24} sm={24} md={12} lg={12} xl={12}>
              <Form.Input
                field='XunhupayGateway'
                label={t('支付网关')}
                placeholder='https://api.xunhupay.com'
                extraText={t('留空则使用默认网关')}
              />
            </Col>
            <Col xs={24} sm={24} md={12} lg={12} xl={12}>
              <Form.InputNumber
                field='XunhupayMinTopUp'
                precision={0}
                label={t('最低充值美元数量')}
                placeholder={t('例如：1')}
                min={1}
              />
            </Col>
          </Row>

          <Button onClick={submitXunhupaySetting} style={{ marginTop: 16 }}>
            {t('更新虎皮椒支付设置')}
          </Button>
        </Form.Section>
      </Form>
    </Spin>
  );
}
