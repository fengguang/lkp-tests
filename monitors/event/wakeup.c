#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

#define PIPE_DIR "/tmp/event_pipe"
#define PID_FILE "/tmp/pid-wakeup"

char *basename(char *path)
{
	char *base = path;

	while (*path)
		if (*path++ == '/')
			base = path;

	return base;
}

void *save_pid(int pid)
{
	FILE *file;

	file = fopen(PID_FILE, "a");
	if (!file) {
		perror(PID_FILE);
		exit(1);
	}

	fprintf(file, "%d\n", pid);

	fclose(file);
}

int main(int argc, char *argv[])
{
	int fd;
	int pid;
	int len;
	char buf[1024];
	char *filename;
	int is_wait;

	if (argc <= 1) {
		printf("Usage: %s PIPE\n", argv[0]);
		exit(0);
	}

	is_wait = !strcmp(basename(argv[0]), "wait");
	filename = argv[1];

	mkdir(PIPE_DIR, 0770);
	chdir(PIPE_DIR);
	mkfifo(filename, 0660);

	if (is_wait)
		fd = open(filename, O_RDONLY);
	else
		fd = open(filename, O_RDWR|O_NONBLOCK);
	if (fd < 0) {
		perror(filename);
		exit(1);
	}

	if (is_wait)
		exit(0);

	len = write(fd, buf, sizeof(buf));
	if (len < sizeof(buf)) {
		fprintf(stderr, "%s: write error or short write: %d\n", argv[0], len);
		exit(1);
	}

	/* keep the fd open for sufficient long time */
	if ((pid = fork())) {
		save_pid(pid);
		exit(0);
	}

	for (--fd; fd; --fd)
		close(fd);
	setsid();
	signal(SIGCHLD, SIG_IGN);
	signal(SIGTSTP, SIG_IGN);
	signal(SIGTTOU, SIG_IGN);
	signal(SIGTTIN, SIG_IGN);

	sleep(100*3600);

	return 0;
}
