#include <endian.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <attr/xattr.h>
#include <linux/types.h>
#include <linux/capability.h>

// set cap_sys_admin=pe for the rootd in arg1 on file in arg2
int main(int argc, char *argv[])
{
	struct vfs_cap_data v;
	char xattrname[100];
	int ret;

	if (argc < 2)
		exit(1);
	memset(&v, 0, sizeof(v));
	if (argc == 2)
		sprintf(xattrname, "security.capability");
	else
		snprintf(xattrname, 100, "security.capability@uid=%s", argv[2]);

	ret = getxattr(argv[1], xattrname, &v, sizeof(v));
	if (ret == sizeof(v))
		exit(0);
	exit(1);
}
