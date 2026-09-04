import { useEffect, useRef, useState } from 'react'
import QRCode from 'qrcode'

const PREFIX = 'routefinder-vehicle:'

/** Renders a scannable QR for a fleet vehicle UUID. */
export function VehicleQR({ vehicleId, label }: { vehicleId: string; label: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !vehicleId) return
    void QRCode.toCanvas(canvas, `${PREFIX}${vehicleId}`, {
      width: 180,
      margin: 1,
      color: { dark: '#0f172a', light: '#ffffff' },
    })
  }, [vehicleId])

  return (
    <div className="qr-block">
      <p className="muted">Driver pairing QR — scan in iOS Fleet setup wizard</p>
      <p>
        <strong>{label}</strong>
      </p>
      <canvas ref={canvasRef} width={180} height={180} aria-label="Vehicle pairing QR code" />
      <p className="mono">
        <code>{vehicleId}</code>
      </p>
      <button
        type="button"
        onClick={async () => {
          await navigator.clipboard.writeText(vehicleId)
          setCopied(true)
          setTimeout(() => setCopied(false), 1500)
        }}
      >
        {copied ? 'Copied' : 'Copy UUID'}
      </button>
    </div>
  )
}
