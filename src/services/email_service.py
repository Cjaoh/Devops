import smtplib
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from src.config import settings

logger = logging.getLogger(__name__)


def _send_email(to: str, subject: str, html: str) -> None:
    """Envoi SMTP bas niveau. Non bloquant : les erreurs sont loguées, pas propagées."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = f"{settings.EMAIL_FROM_NAME} <{settings.SMTP_FROM}>"
    msg["To"]      = to
    msg.attach(MIMEText(html, "html", "utf-8"))
    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_FROM, to, msg.as_string())
        logger.info("Email envoyé à %s — %s", to, subject)
    except Exception as exc:
        logger.error("Échec envoi email à %s : %s", to, exc)


def send_reservation_confirmation(reservation) -> None:
    """Envoie un email de confirmation après création d'une réservation."""
    user     = reservation.user
    resource = reservation.resource
    subject  = f"✅ Confirmation réservation #{reservation.id} — {resource.name}"
    html = f"""
    <html><body style="font-family:Arial,sans-serif;color:#333;max-width:600px;margin:auto">
      <h2 style="color:#2563eb">Réservation confirmée</h2>
      <p>Bonjour <strong>{user.full_name}</strong>,</p>
      <p>Votre réservation a bien été enregistrée :</p>
      <table style="border-collapse:collapse;width:100%;margin-top:12px">
        <tr style="background:#f3f4f6">
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Ressource</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">{resource.name}</td>
        </tr>
        <tr>
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Type</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">{resource.type}</td>
        </tr>
        <tr style="background:#f3f4f6">
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Début</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">{reservation.start_at.strftime('%d/%m/%Y à %H:%M')}</td>
        </tr>
        <tr>
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Fin</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">{reservation.end_at.strftime('%d/%m/%Y à %H:%M')}</td>
        </tr>
        <tr style="background:#f3f4f6">
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Motif</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">{reservation.purpose or '—'}</td>
        </tr>
        <tr>
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Référence</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">#{reservation.id}</td>
        </tr>
      </table>
      <p style="margin-top:16px;color:#6b7280;font-size:14px">
        Pour annuler ou modifier, connectez-vous à votre espace personnel.
      </p>
      <hr style="margin-top:24px;border:none;border-top:1px solid #e5e7eb">
      <p style="font-size:12px;color:#9ca3af">{settings.APP_NAME} — message automatique, ne pas répondre.</p>
    </body></html>
    """
    _send_email(user.email, subject, html)


def send_reservation_cancellation(reservation) -> None:
    """Envoie un email de notification d'annulation."""
    user     = reservation.user
    resource = reservation.resource
    subject  = f"❌ Annulation réservation #{reservation.id} — {resource.name}"
    html = f"""
    <html><body style="font-family:Arial,sans-serif;color:#333;max-width:600px;margin:auto">
      <h2 style="color:#dc2626">Réservation annulée</h2>
      <p>Bonjour <strong>{user.full_name}</strong>,</p>
      <p>La réservation suivante a été annulée :</p>
      <table style="border-collapse:collapse;width:100%;margin-top:12px">
        <tr style="background:#f3f4f6">
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Ressource</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">{resource.name}</td>
        </tr>
        <tr>
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Créneau</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">
            {reservation.start_at.strftime('%d/%m/%Y %H:%M')} → {reservation.end_at.strftime('%d/%m/%Y %H:%M')}
          </td>
        </tr>
        <tr style="background:#f3f4f6">
          <td style="padding:10px;border:1px solid #e5e7eb"><strong>Référence</strong></td>
          <td style="padding:10px;border:1px solid #e5e7eb">#{reservation.id}</td>
        </tr>
      </table>
      <p style="margin-top:16px;color:#6b7280;font-size:14px">
        Si cette annulation est une erreur, vous pouvez recréer une réservation depuis votre espace.
      </p>
      <hr style="margin-top:24px;border:none;border-top:1px solid #e5e7eb">
      <p style="font-size:12px;color:#9ca3af">{settings.APP_NAME} — message automatique, ne pas répondre.</p>
    </body></html>
    """
    _send_email(user.email, subject, html)
