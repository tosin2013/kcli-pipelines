# kcli-pipelines

Edit and run the trigger pipeline to trigger a build.


![20230527093215](https://i.imgur.com/I9ERA5a.png)

```bash
$ vim trigger-pipeline.sh

TOKEN="GITLAB-TOKEN"
SSH_PASSWORD="MACHINE_PASSWORD"
TARGET_SERVER=equinix
SSH_HOST="192.168.1.25"
SSH_USER="lab-user"
ACTION=create #delete
```

Run thhe pipeline
```
$ ./trigger-pipeline.sh
```