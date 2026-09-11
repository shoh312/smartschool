package tj.cict.smartflow.data.dto

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

object LocalDateSerializer : KSerializer<LocalDate> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("LocalDate", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: LocalDate) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): LocalDate = LocalDate.parse(decoder.decodeString().take(10))
}

/**
 * The servers write naive ISO timestamps in the school's own local time.
 * Anything with an offset is also accepted, dropped to wall-clock time, so
 * a future change to aware timestamps does not break old builds.
 */
object LocalDateTimeSerializer : KSerializer<LocalDateTime> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("LocalDateTime", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: LocalDateTime) =
        encoder.encodeString(value.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))

    override fun deserialize(decoder: Decoder): LocalDateTime {
        val raw = decoder.decodeString()
        return runCatching { LocalDateTime.parse(raw) }
            .recoverCatching { OffsetDateTime.parse(raw).toLocalDateTime() }
            .getOrElse { LocalDate.parse(raw.take(10)).atStartOfDay() }
    }
}
