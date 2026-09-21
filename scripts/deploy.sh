#!/bin/bash
set -euo pipefail

VERSION=$1

if [ -z "$VERSION" ]; then 
       echo "empty version"
       exit 1
fi

TARFILE=/home/user/images/flask-app-${VERSION}.tar


if [ ! -f "$TARFILE" ]; then
	echo "not found $TARFILE "
	exit 1
fi

scp "$TARFILE" user@10.0.10.11:/home/user 
scp "$TARFILE" user@10.0.10.12:/home/user

ssh user@10.0.10.11 << EOF 
sudo k3s ctr images import /home/user/flask-app-${VERSION}.tar
sudo k3s ctr images ls | grep flask
EOF

ssh user@10.0.10.12  << EOF
sudo k3s ctr images import  /home/user/flask-app-${VERSION}.tar
sudo k3s ctr images ls | grep flask
EOF


ssh user@10.0.10.10 << EOF
sudo kubectl set image deployment/flask-app flask-app=flask-app:${VERSION}
sudo kubectl rollout status deployment/flask-app
EOF

