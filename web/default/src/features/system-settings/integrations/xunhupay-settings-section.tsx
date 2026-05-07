import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { SettingsSection } from '../components/settings-section'
import { useUpdateOption } from '../hooks/use-update-option'

export interface XunhupaySettingsValues {
  XunhupayEnabled: boolean
  XunhupayAppId: string
  XunhupayAppSecret: string
  XunhupayGateway: string
  XunhupayMinTopUp: number
}

interface Props {
  defaultValues: XunhupaySettingsValues
}

export function XunhupaySettingsSection(props: Props) {
  const { t } = useTranslation()
  const updateOption = useUpdateOption()
  const [loading, setLoading] = useState(false)

  const form = useForm<XunhupaySettingsValues>({
    defaultValues: props.defaultValues,
  })

  useEffect(() => {
    form.reset(props.defaultValues)
  }, [props.defaultValues, form])

  const handleSave = async () => {
    setLoading(true)
    try {
      const values = form.getValues()
      const options: { key: string; value: string }[] = [
        { key: 'XunhupayEnabled', value: String(values.XunhupayEnabled) },
        { key: 'XunhupayAppId', value: values.XunhupayAppId || '' },
        { key: 'XunhupayGateway', value: values.XunhupayGateway || '' },
        { key: 'XunhupayMinTopUp', value: String(values.XunhupayMinTopUp || 1) },
      ]
      if (values.XunhupayAppSecret)
        options.push({ key: 'XunhupayAppSecret', value: values.XunhupayAppSecret })

      for (const opt of options) {
        await updateOption.mutateAsync(opt)
      }
      toast.success(t('Updated successfully'))
    } catch {
      toast.error(t('Update failed'))
    } finally {
      setLoading(false)
    }
  }

  return (
    <SettingsSection
      title={t('虎皮椒支付设置')}
      description={t('Configure Xunhupay (WeChat Pay) integration')}
    >
      <Alert>
        <AlertDescription className='text-xs'>
          {t('请先在虎皮椒支付平台注册账号并创建应用，获取 AppID 和 AppSecret。回调地址请填写:')}{' '}
          <code className='rounded bg-muted px-1 py-0.5 text-xs'>
            {'<ServerAddress>/api/xunhupay/webhook'}
          </code>
        </AlertDescription>
      </Alert>

      <div className='flex items-center gap-2'>
        <Switch
          checked={form.watch('XunhupayEnabled')}
          onCheckedChange={(v) => form.setValue('XunhupayEnabled', v)}
        />
        <Label>{t('Enable Xunhupay')}</Label>
      </div>

      <div className='grid grid-cols-2 gap-4'>
        <div className='grid gap-1.5'>
          <Label>{t('AppID')}</Label>
          <Input {...form.register('XunhupayAppId')} placeholder='10001' />
        </div>
        <div className='grid gap-1.5'>
          <Label>{t('App Secret')}</Label>
          <Input
            type='password'
            {...form.register('XunhupayAppSecret')}
            placeholder={t('Enter new secret to update')}
          />
        </div>
      </div>

      <div className='grid gap-1.5'>
        <Label>{t('Payment Gateway')}</Label>
        <Input
          {...form.register('XunhupayGateway')}
          placeholder='https://api.xunhupay.com'
        />
      </div>

      <div className='grid gap-1.5'>
        <Label>{t('Minimum top-up (USD)')}</Label>
        <Input
          type='number'
          min={1}
          {...form.register('XunhupayMinTopUp', { valueAsNumber: true })}
        />
      </div>

      <Button onClick={handleSave} disabled={loading}>
        {loading ? t('Saving...') : t('Save Changes')}
      </Button>
    </SettingsSection>
  )
}
