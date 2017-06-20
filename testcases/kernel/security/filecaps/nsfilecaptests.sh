#!/bin/sh
################################################################################
##                                                                            ##
## This program is free software;  you can redistribute it and#or modify      ##
## it under the terms of the GNU General Public License as published by       ##
## the Free Software Foundation; either version 2 of the License, or          ##
## (at your option) any later version.                                        ##
##                                                                            ##
## This program is distributed in the hope that it will be useful, but        ##
## WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY ##
## or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License   ##
## for more details.                                                          ##
##                                                                            ##
## You should have received a copy of the GNU General Public License          ##
## along with this program;  if not, write to the Free Software               ##
## Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA    ##
##                                                                            ##
################################################################################

TCID="nsfilecaps"
TST_TOTAL=13
TST_CLEANUP=finish
. test.sh

TEST_USER=fcaptest

finish() {
	rm -f sleepx
	userdel $TEST_USER
	sed -i '/root:300000:200001/d' /etc/subgid /etc/subuid
	exit $exit_code
}

groupadd $TEST_USER
useradd -g $TEST_USER $TEST_USER -s /bin/sh

rm -f sleepx
sleep=`which sleep`
cp $sleep sleepx
failed=false
echo "testing unprivileged user setting filecaps"

chown $TEST_USER:$TEST_USER sleepx
su $TEST_USER -c "setcap cap_sys_admin+pe sleepx" || failed=true
if [ "$failed" = "true" ]; then
	tst_resm TPASS "Unpriv user cannot set filecaps"
else
	tst_resm TFAIL "Unpriv user can set filecaps"
fi

chown 0:0 sleepx

echo "testing privileged user setting filecaps"
setcap cap_sys_admin+pe sleepx
if [ $? -eq 0 ]; then
	tst_resm TPASS "Root can set filecaps"
else
	tst_resm TFAIL "Root cannot set filecaps"
fi

setcap -r sleepx
usermod -v 300000-500000 -w 300000-500000 root

lxc-usernsexec -m b:0:300000:1 -m b:1:0:1 -- chown 0:0 sleepx

echo "testing unpriv container user setting v2 filecap"
failed=false
lxc-usernsexec -m b:0:300000:100000 -- tst_su $TEST_USER setcap cap_sys_admin+pe sleepx || failed=true
if [ "$failed" = "true" ]; then
	tst_resm TPASS "Unpriv container user cannot set v2 filecap"
else
	tst_resm TFAIL "Unpriv container user can set v2 filecap"
fi

setcap -r sleepx

echo "testing container root user using v2 filecap"
lxc-usernsexec -m b:0:300000:100000 -- setcap cap_sys_admin+pe sleepx
if [ $? -eq 0 ]; then
	tst_resm TPASS "Container root can set virtualized v2 caps"
else
	tst_resm TFAIL "Container root cannot set virtualized v2 caps"
fi

echo "testing container user reading filecap"
lxc-usernsexec -m b:0:300000:100000 -- getcap sleepx | grep "sleepx = cap_sys_admin+ep"
if [ $? -eq 0 ]; then
	tst_resm TPASS "Container user can read virtualized v2 caps"
else
	tst_resm TFAIL "Container user cannot read virtualized v2 caps"
fi

echo "testing global user reading filecap"
o=`getcap sleepx`
if [ -z "$o" ]; then
	tst_resm TPASS "Global root does not see child's virtualized caps"
else
	tst_resm TFAIL "Global root sees child's virtualized caps"
fi

fullpath="$(pwd)/sleepx"
echo "testing container user using virtualized filecap"
(lxc-usernsexec -m b:0:300000:100000 -- su - $TEST_USER -c "${fullpath} 60" ) &
p=$!
sleep 2
# child of lxc-usernsexec is su; child of su is sleepx- no there's also a "-su"
p3=`pidof sleepx`
echo "ps $p p2 is $p2 p3 is $p3"
if grep "CapEff:.*0000000000200000" /proc/$p3/status; then
	tst_resm TPASS "Container user is granted filecaps"
else
	tst_resm TFAIL "Container user is not granted filecaps"
fi
ps -ef | grep sleepx | awk '{ print $2 }' | xargs kill -9
kill -9 $p
sleep 1

echo "testing global user ignoring virtualized filecap"
(su - $TEST_USER -c "${fullpath} 60" ) &
p=$!
sleep 2
p2=`pidof sleepx`
if grep "CapEff:.*0000000000000000" /proc/$p2/status; then
	tst_resm TPASS "user in init_user_ns is not granted container filecaps"
else
	tst_resm TFAIL "user in init_user_ns is granted container filecaps"
fi
ps -ef | grep sleepx | awk '{ print $2 }' | xargs kill -9
kill -9 $p
sleep 1

echo "testing cousin container ignoring virtualized filecap"
(lxc-usernsexec -m b:0:300001:100000 -- su - $TEST_USER -c "${fullpath} 60" ) &
p=$!
sleep 2
p3=`pidof sleepx`
if grep "CapEff:.*0000000000000000" /proc/$p3/status; then
	tst_resm TPASS "cousin container user is not granted container filecaps"
else
	tst_resm TFAIL "cousin container user is granted container filecaps"
fi
kill -9 $p

setcap -r ${fullpath}

echo "testing writing a v3 filecap with rootid 0 in container"
lxc-usernsexec -m b:0:300000:2 -- setv3xattr 0 ${fullpath}
if ! getv3xattr ${fullpath}`; then
	tst_resm TFAIL "wrong v3 rootid was written"
else
	tst_resm TPASS "v3 rootid was written correctly"
fi

echo "testing writing a v3 filecap with rootid 1 in container"
lxc-usernsexec -m b:0:300000:2 -- setv3xattr 1 ${fullpath}
if ! getv3xattr ${fullpath} 300001`; then
	tst_resm TFAIL "wrong v3 rootid was written"
else
	tst_resm TPASS "v3 rootid was written correctly"
fi

echo "testing writing a v3 filecap with rootid 2 (invalid) in container"
# setv3xattr should have failed, and the previous xattr value should remain
lxc-usernsexec -m b:0:300000:2 -- setv3xattr 2 ${fullpath}
ret=$?
if [ $ret -eq 0 ]; then
	tst_resm TFAIL "invalid setv3xattr succeeded"
else
	tst_resm TPASS "invalid setv3xattr failed correctly"
fi

tst_exit
