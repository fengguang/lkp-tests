#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

char *get_tmp_dir(void)
{
	char *tmp;

	tmp = getenv("TMP");
	if (tmp)
		return tmp;
	else
		return "/tmp";
}

char *get_pipe_dir(void)
{
	static char pipe_dir[2048];

	if (!pipe_dir[0])
		snprintf(pipe_dir, sizeof(pipe_dir), "%s/event_pipe",
			 get_tmp_dir());
	return pipe_dir;
}

char *get_pid_file(void)
{
	static char pid_file[2048];

	if (!pid_file[0])
		snprintf(pid_file, sizeof(pid_file), "%s/pid-wakeup",
			 get_tmp_dir());
	return pid_file;
}

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
	char *pid_file = get_pid_file();

	file = fopen(pid_file, "a");
	if (!file) {
		perror(pid_file);
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
	char *pipe_dir = get_pipe_dir();

	if (argc <= 1) {
		printf("Usage: %s PIPE\n", argv[0]);
		exit(0);
	}

	is_wait = !strcmp(basename(argv[0]), "wait");
	filename = argv[1];

	mkdir(pipe_dir, 0770);
	chdir(pipe_dir);
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
