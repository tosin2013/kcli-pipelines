import os
import sys

if not os.environ.get('SSH_PASSWORD'):
    print("Environment variable SSH_PASSWORD is not set. Exiting.", file=sys.stderr)
    sys.exit(1)

if not os.environ.get('SSH_USER'):
    print("Environment variable SSH_USER is not set. Exiting.", file=sys.stderr)
    sys.exit(1)

if not os.environ.get('SSH_HOST'):
    print("Environment variable SSH_HOST is not set. Exiting.", file=sys.stderr)
    sys.exit(1)


if not os.environ.get('TARGET_SERVER'):
    print("Environment variable TARGET_SERVER is not set. Exiting.", file=sys.stderr)
    sys.exit(1)

if os.environ.get('VM_NAME'):
    if not os.environ.get('ACTION'):
        print("Environment variable ACTION is not set. Exiting.", file=sys.stderr)
        sys.exit(1)
