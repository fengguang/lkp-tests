#!/bin/sh

job_failed_content()
{
	email_content="To: $my_email
Subject: [NOTIFY Compass-CI] Test job failed: $id

Dear $my_name:

	Sorry to inform you that your test job is failed, you can click the following link to view details.
	http://api.compass-ci.openeuler.org:${SRV_HTTP_PORT:-11300}$result_root

Regards
Compass-CI
"
}

send_email()
{
	local subject=$1
	local email_content

	${subject}_content

	curl -XPOST "${MAIL_HOST:-$LKP_SERVER}:${MAIL_PORT:-49000}/send_mail_text" -d "$email_content"
}
