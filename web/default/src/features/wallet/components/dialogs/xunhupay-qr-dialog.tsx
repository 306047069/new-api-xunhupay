import { useTranslation } from 'react-i18next'
import { QRCodeSVG } from 'qrcode.react'
import { Copy, Check, ExternalLink } from 'lucide-react'
import { useState } from 'react'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import type { XunhupayQrData } from '../../hooks/use-xunhupay-payment'

interface Props {
  open: boolean
  onOpenChange: (open: boolean) => void
  qrData: XunhupayQrData | null
}

export function XunhupayQrDialog({ open, onOpenChange, qrData }: Props) {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)

  if (!qrData) return null

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(qrData.qr_url)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

  const isUrl = qrData.qr_url.startsWith('http')

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className='sm:max-w-md'>
        <DialogHeader>
          <DialogTitle>{t('微信支付')}</DialogTitle>
          <DialogDescription>
            {t('请使用微信扫一扫完成支付，订单号:')}{' '}
            <span className='font-mono text-xs'>{qrData.order_id}</span>
          </DialogDescription>
        </DialogHeader>

        <div className='flex flex-col items-center gap-4 py-4'>
          {isUrl ? (
            <div className='rounded-lg border bg-white p-4'>
              <QRCodeSVG value={qrData.qr_url} size={200} level='M' />
            </div>
          ) : (
            <div className='rounded-lg border bg-white p-4'>
              <QRCodeSVG value={qrData.qr_url} size={200} level='M' />
            </div>
          )}

          <div className='text-muted-foreground text-sm'>
            {t('充值金额:')} <span className='font-semibold text-foreground'>{qrData.amount}</span>
          </div>

          <div className='flex w-full gap-2'>
            <Button
              variant='outline'
              className='flex-1 gap-2'
              onClick={handleCopy}
            >
              {copied ? (
                <Check className='h-4 w-4 text-green-500' />
              ) : (
                <Copy className='h-4 w-4' />
              )}
              {copied ? t('Copied') : t('Copy payment URL')}
            </Button>
            {isUrl && (
              <Button
                variant='outline'
                className='gap-2'
                onClick={() => window.open(qrData.qr_url, '_blank')}
              >
                <ExternalLink className='h-4 w-4' />
                {t('Open')}
              </Button>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
