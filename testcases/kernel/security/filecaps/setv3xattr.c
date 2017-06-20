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
	int ret;
	int rootid;
	char xattrname[100];

	if (argc != 3)
		exit(1);
	rootid = atoi(argv[1]);
	memset(&v, 0, sizeof(v));

	v.data[0].permitted = htole32(1 << CAP_SYS_ADMIN);
	v.magic_etc = htole32(0x02000000 | 0x000001); // v3 cap and set effective
	snprintf(xattrname, 100, "security.capability@uid=%d", rootid);
	ret = setxattr(argv[2], xattrname, &v, sizeof(v), 0);
	if (ret < 0)
		exit(errno);
	exit(0);
}
