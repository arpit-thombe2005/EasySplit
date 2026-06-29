import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

export const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: {
    rejectUnauthorized: false,
  },
});

export async function sendGroupBackupEmail({ toEmail, groupName, excelBuffer, pdfBuffer, excelFilename, pdfFilename }) {
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
    from: `"EasySplit" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: `EasySplit - Final Expense Reports for "${groupName}"`,
    text: `Hello,\n\nThe group "${groupName}" has been finalized and permanently deleted by the group owner.\n\nFor your records, we have attached the complete expense history, analytics summary, settlements, balances, and simplified settlement summary in both Excel (.xlsx) and PDF (.pdf) formats.\n\nThank you for using EasySplit.`,
    html: `
      <div style="font-family: sans-serif; padding: 20px; color: #333;">
        <h2>EasySplit - Final Expense Reports</h2>
        <p>Hello,</p>
        <p>The group <strong>"${groupName}"</strong> has been finalized and permanently deleted by the group owner.</p>
        <p>For your records, we have attached the complete expense history, analytics summary, settlements, balances, and simplified settlement summary as both <strong>Excel (.xlsx)</strong> and <strong>PDF (.pdf)</strong> reports.</p>
        <br/>
        <p>Thank you for using EasySplit.</p>
      </div>
    `,
    attachments,
  };

  return await transporter.sendMail(mailOptions);
}
