import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

const isGmail = process.env.SMTP_HOST?.includes('gmail') || process.env.SMTP_USER?.includes('gmail');

export const transporter = nodemailer.createTransport(
  isGmail
    ? {
        service: 'gmail',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      }
    : {
        host: process.env.SMTP_HOST || 'smtp.gmail.com',
        port: parseInt(process.env.SMTP_PORT || '465'),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      }
);

export async function sendGroupBackupEmail({ toEmail, groupName, excelBuffer, pdfBuffer, excelFilename, pdfFilename }) {
  const senderEmail = process.env.SMTP_USER || 'easysplit2026@gmail.com';
  const subject = `EasySplit - Final Expense Reports for "${groupName}"`;
  const textContent = `Hello,\n\nThe group "${groupName}" has been finalized and permanently deleted by the group owner.\n\nFor your records, we have attached the complete expense history, analytics summary, settlements, balances, and simplified settlement summary in both Excel (.xlsx) and PDF (.pdf) formats.\n\nThank you for using EasySplit.`;
  const htmlContent = `
    <div style="font-family: sans-serif; padding: 20px; color: #333;">
      <h2>EasySplit - Final Expense Reports</h2>
      <p>Hello,</p>
      <p>The group <strong>"${groupName}"</strong> has been finalized and permanently deleted by the group owner.</p>
      <p>For your records, we have attached the complete expense history, analytics summary, settlements, balances, and simplified settlement summary as both <strong>Excel (.xlsx)</strong> and <strong>PDF (.pdf)</strong> reports.</p>
      <br/>
      <p>Thank you for using EasySplit.</p>
    </div>
  `;

  // 1. Resend API support (HTTP REST - 100% reliable on cloud hosts)
  if (process.env.RESEND_API_KEY) {
    const attachments = [];
    if (excelBuffer && excelFilename) {
      attachments.push({
        filename: excelFilename,
        content: excelBuffer.toString('base64'),
      });
    }
    if (pdfBuffer && pdfFilename) {
      attachments.push({
        filename: pdfFilename,
        content: pdfBuffer.toString('base64'),
      });
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.EMAIL_FROM || 'EasySplit <onboarding@resend.dev>',
        to: [toEmail],
        subject: subject,
        html: htmlContent,
        attachments,
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Resend API error (${res.status}): ${errText}`);
    }
    return;
  }

  // 2. Brevo (Sendinblue) API support (HTTP REST)
  if (process.env.BREVO_API_KEY) {
    const attachment = [];
    if (excelBuffer && excelFilename) {
      attachment.push({
        name: excelFilename,
        content: excelBuffer.toString('base64'),
      });
    }
    if (pdfBuffer && pdfFilename) {
      attachment.push({
        name: pdfFilename,
        content: pdfBuffer.toString('base64'),
      });
    }

    const res = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': process.env.BREVO_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        sender: { name: 'EasySplit', email: senderEmail },
        to: [{ email: toEmail }],
        subject: subject,
        htmlContent: htmlContent,
        attachment,
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Brevo API error (${res.status}): ${errText}`);
    }
    return;
  }

  // 3. Fallback to standard Nodemailer SMTP
  const attachments = [];
  if (excelBuffer && excelFilename) {
    attachments.push({
      filename: excelFilename,
      content: excelBuffer,
      contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
  }
  if (pdfBuffer && pdfFilename) {
    attachments.push({
      filename: pdfFilename,
      content: pdfBuffer,
      contentType: 'application/pdf',
    });
  }

  const mailOptions = {
    from: `"EasySplit" <${senderEmail}>`,
    to: toEmail,
    subject: subject,
    text: textContent,
    html: htmlContent,
    attachments,
  };

  return await transporter.sendMail(mailOptions);
}
