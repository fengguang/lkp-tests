#!/bin/sh

job_failed_content()
{
	email_content="To: $my_email
Subject: [NOTIFY Compass-CI] Test job failed: $id

Dear $my_name:

	Sorry to inform you that your test job is failed, you can click the following link to view details.
	https://api.compass-ci.openeuler.org:${SRV_HTTP_RESULT_PORT:-20007}$result_root

Regards
Compass-CI
"
}

job_debug_content()
{
	email_content="To: $my_email
Subject: [NOTIFY Compass-CI] Test job debug: $id

Dear $my_name,

	Your test job is ready to debug and test machine has been provisioned.

	Login:
		ssh root@api.compass-ci.openeuler.org -p $port
	Due time:
		$deadline
	HW:
		nr_cpu: $nr_cpu
		memory: $memory
		testbox: $testbox
	OS:
		$os $os_version $os_arch

Regards
Compass-CI
"
}

borrow_success_content()
{
	email_content="To: $my_email
Subject: [NOTIFY Compass-CI] Machine application successful: $id

Dear $my_name,

	Your test machine has been provisioned.

	Login:
		ssh root@api.compass-ci.openeuler.org -p $port
	Due time:
		$deadline
	HW:
		nr_cpu: $nr_cpu
		memory: $memory
		testbox: $testbox
	OS:
		$os $os_version $os_arch

Regards
Compass-CI
"
}

borrow_failed_content()
{
	email_content="To: $my_email
Subject: [NOTIFY Compass-CI] Machine application failed: $id

Dear $my_name:

	Sorry to inform you that your application failed.
	You may need to wait a moment, or check whether your pub_key exists.

Regards
Compass-CI
"
}

selftest_content()
{
	email_content=$(echo "To: $recipient_email
Subject: [NOTIFY Compass-CI] Self-test report

Dear $author_name and $committer:

	commit_id: $commit_id

	commit_subject: $commit_subject

	Your self-test job $id result is:

	$report_content

Regards
Compass-CI
" | base64)
}

selftest_env_content()
{
	email_content=$(echo "To: $recipient_email_to
Bcc: $recipient_email_bcc
Subject: [SELF-TEST] REPORT

Dear All:

group_id: $group_id

$report_content

Regards
Compass-CI
" | base64)
}

rpmbuild_report()
{
	email_content="To: $author_email
Subject: [NOTIFY Compass-CI] rpmbuild report

Dear $author_name:

FYI, you triggered the rpm build due to commit:

commit: $upstream_commit
$upstream_url/commit/$upstream_commit $upstream_branch

	$rpmbuild_result

Regards
Compass-CI
"
}

rpmbuild_success_content()
{
	rpmbuild_result="Your RPM Package is successfully built.

You can click the follow link to obtain your RPM Package:
https://api.compass-ci.openeuler.org:20018/rpm/testing/${os}-${os_version}/${compat_os}/${os_arch}/Packages

And you can click the following link to view RPM Package build details:
https://api.compass-ci.openeuler.org:${SRV_HTTP_RESULT_PORT:-20007}$result_root"

	rpmbuild_report
}

rpmbuild_failed_content()
{
	rpmbuild_result="We noticed that rpm build failed due to the commit, you can click the following link to view details.
https://api.compass-ci.openeuler.org:${SRV_HTTP_RESULT_PORT:-20007}$result_root/output

You can obtain more information by clicking on the link below
https://api.compass-ci.openeuler.org:${SRV_HTTP_RESULT_PORT:-20007}$result_root"

	rpmbuild_report
}

errors_env_content()
{
	email_content=$(echo "To: $recipient_email_to
Bcc: $recipient_email_bcc
Subject: $mail_subject

$report_content

Regards
Compass-CI
" | base64)
}

send_email()
{
	local subject=$1
	local email_content

	${subject}_content

	curl -XPOST "${SEND_MAIL_HOST:-$LKP_SERVER}:${SEND_MAIL_PORT:-10001}/send_mail_text" -d "$email_content"
}

send_email_encode()
{
	local subject=$1
	local email_content

	${subject}_content

	curl -XPOST "${SEND_MAIL_HOST:-$LKP_SERVER}:${SEND_MAIL_PORT:-10001}/send_mail_encode" -d "$email_content"
}

local_send_email()
{
	local subject=$1
	local email_content

	${subject}_content

	curl -XPOST "${SEND_MAIL_HOST:-$LKP_SERVER}:${LOCAL_SEND_MAIL_PORT:-11311}/send_mail_text" -d "$email_content"
}

local_send_email_encode()
{
	local subject=$1
	local email_content

	${subject}_content

	curl -XPOST "${SEND_MAIL_HOST:-$LKP_SERVER}:${LOCAL_SEND_MAIL_PORT:-11311}/send_mail_encode" -d "$email_content"
}
