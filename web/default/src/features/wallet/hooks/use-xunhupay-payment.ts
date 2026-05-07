import { useState, useCallback } from 'react'
import i18next from 'i18next'
import { toast } from 'sonner'
import { requestXunhupayPayment, isApiSuccess } from '../api'

export interface XunhupayQrData {
  qr_url: string
  order_id: string
  amount: number
}

export function useXunhupayPayment() {
  const [processing, setProcessing] = useState(false)
  const [qrData, setQrData] = useState<XunhupayQrData | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)

  const processXunhupayPayment = useCallback(
    async (topupAmount: number) => {
      setProcessing(true)
      try {
        const response = await requestXunhupayPayment({
          amount: Math.floor(topupAmount),
        })

        if (isApiSuccess(response) && response.data) {
          const data = response.data as XunhupayQrData
          if (data.qr_url) {
            setQrData(data)
            setDialogOpen(true)
            return true
          }
        }

        toast.error(
          (response.message as string) || i18next.t('Payment request failed')
        )
        return false
      } catch (_error) {
        toast.error(i18next.t('Payment request failed'))
        return false
      } finally {
        setProcessing(false)
      }
    },
    []
  )

  const closeDialog = useCallback(() => {
    setDialogOpen(false)
    setQrData(null)
  }, [])

  return {
    processing,
    qrData,
    dialogOpen,
    processXunhupayPayment,
    closeDialog,
  }
}
