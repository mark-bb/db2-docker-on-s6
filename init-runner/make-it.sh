f=init-runner
gcc -s -o ${f?} ${f?}.c
chown root:root ${f?}
chmod u+s ${f?}
