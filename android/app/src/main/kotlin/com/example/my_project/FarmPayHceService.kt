package com.mycompany.farm

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * Emulates an NFC Forum Type 4 tag holding one NDEF URI record "farmpay:<token>".
 * The token is a short-lived, backend-signed request; the reader fetches the real
 * amount/payee from the backend. Only active while the Receive screen sets a token.
 */
class FarmPayHceService : HostApduService() {
  companion object {
    @Volatile var token: String? = null
    @Volatile var expiresAtMs: Long = 0

    private val OK = byteArrayOf(0x90.toByte(), 0x00)
    private val NOT_FOUND = byteArrayOf(0x6A.toByte(), 0x82.toByte())
    private val NDEF_AID = byteArrayOf(0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01)
    private val CC_FILE = byteArrayOf(
      0x00, 0x0F, 0x20, 0x00, 0x3B, 0x00, 0x34, 0x04, 0x06, 0xE1.toByte(), 0x04,
      0x02, 0x00, 0x00, 0xFF.toByte()
    )
  }

  private var selected = 0 // 1 = CC, 2 = NDEF

  private fun ndefFile(): ByteArray? {
    val t = token ?: return null
    if (System.currentTimeMillis() > expiresAtMs) return null
    val uri = "farmpay:$t".toByteArray(Charsets.UTF_8)
    val payload = byteArrayOf(0x00) + uri // 0x00 = no URI prefix abbreviation
    val record = byteArrayOf(0xD1.toByte(), 0x01, payload.size.toByte(), 0x55) + payload
    val len = record.size
    return byteArrayOf((len shr 8).toByte(), (len and 0xFF).toByte()) + record
  }

  override fun processCommandApdu(apdu: ByteArray, extras: Bundle?): ByteArray {
    if (apdu.size < 4) return NOT_FOUND
    val ins = apdu[1].toInt() and 0xFF
    when (ins) {
      0xA4 -> { // SELECT
        val data = if (apdu.size > 5) apdu.copyOfRange(5, 5 + (apdu[4].toInt() and 0xFF)) else ByteArray(0)
        return when {
          data.contentEquals(NDEF_AID) -> if (ndefFile() != null) OK else NOT_FOUND
          data.contentEquals(byteArrayOf(0xE1.toByte(), 0x03)) -> { selected = 1; OK }
          data.contentEquals(byteArrayOf(0xE1.toByte(), 0x04)) -> { selected = 2; OK }
          else -> NOT_FOUND
        }
      }
      0xB0 -> { // READ BINARY
        val file = when (selected) { 1 -> CC_FILE; 2 -> ndefFile(); else -> null } ?: return NOT_FOUND
        val offset = ((apdu[2].toInt() and 0xFF) shl 8) or (apdu[3].toInt() and 0xFF)
        val le = if (apdu.size > 4) (apdu[4].toInt() and 0xFF).let { if (it == 0) 256 else it } else 256
        if (offset > file.size) return NOT_FOUND
        val end = minOf(file.size, offset + le)
        return file.copyOfRange(offset, end) + OK
      }
    }
    return NOT_FOUND
  }

  override fun onDeactivated(reason: Int) { selected = 0 }
}
