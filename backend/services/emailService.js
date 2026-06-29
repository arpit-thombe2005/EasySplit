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

export async function sendGroupBackupEmail({ toEmail, groupName, excelBuffer, filename }) {
  const mailOptions = {
    from: `"EasySplit" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: `EasySplit - Final Expense Report for "${groupName}"`,
    text: `Hello,\n\nThe group "${groupName}" has been deleted by the group owner.\n\nFor your records, we have attached the complete expense history, settlements, balances, and final simplified settlement summary.\n\nThank you for using EasySplit.`,
    html: `
      <div style="font-family: sans-serif; padding: 20px; color: #333;">
        <h2>EasySplit - Final Expense Report</h2>
        <p>Hello,</p>
        <p>The group <strong>"${groupName}"</strong> has been deleted by the group owner.</p>
        <p>For your records, we have attached the complete expense history, settlements, balances, and final simplified settlement summary as an Excel report.</p>
        <br/>
        <p>Thank you for using EasySplit.</p>
      </div>
    `,
    attachments: [
      {
        filename: filename,
        content: excelBuffer,
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
    ],
  };

  return await transporter.sendMail(mailOptions);
}
