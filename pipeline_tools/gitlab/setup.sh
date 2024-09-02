#!/bin/bash

# Name of the virtual environment directory
VENV_DIR="venv"

# Create the virtual environment
python -m venv $VENV_DIR
echo "Virtual environment created at ./$VENV_DIR"

# Activate the virtual environment
source $VENV_DIR/bin/activate
pip install pip-tools
pip-compile pipeline_tools/gitlab/requirements.in
pip install -r pipeline_tools/gitlab/requirements.txt

echo "Virtual environment activated."
source $VENV_DIR/bin/activate
echo "source $VENV_DIR/bin/activate"
export STREAMLIT_SERVER_ADDRESS=localhost
streamlit run pipeline_tools/gitlab/app.py
#USER=gitlab-runner
#usermod -aG wheel ${USER}
#echo "${USER} ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/${USER}
#chmod 0440 /etc/sudoers.d/${USER}

