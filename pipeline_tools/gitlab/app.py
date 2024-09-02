import streamlit as st
import requests
import sqlite3
import json
import yaml
import os

# Load configuration from config.yaml
with open('pipeline_tools/gitlab/config.yaml', 'r') as file:
    config = yaml.safe_load(file)

# Set up SQLite database
conn = sqlite3.connect('pipeline_variables.db')
c = conn.cursor()
c.execute('''
    CREATE TABLE IF NOT EXISTS variables (
        id INTEGER PRIMARY KEY,
        job_type TEXT,
        GIT_REPO TEXT,
        CICD_PIPELINE TEXT,
        TARGET_SERVER TEXT,
        VM_PROFILE TEXT,
        ACTION TEXT,
        COMMUNITY_VERSION TEXT,
        DEPLOY_OPENSHIFT TEXT,
        LAUNCH_STEPS TEXT,
        TAG TEXT,
        DISCONNECTED_INSTALL TEXT,
        DEPLOYMENT_CONFIG TEXT,
        GUID TEXT,
        IP_ADDRESS TEXT,
        ZONE_NAME TEXT,
        VERBOSE_LEVEL TEXT,
        status TEXT
    )
''')
conn.commit()

# Helper function to set GitLab CI/CD variables
def set_gitlab_variable(project_id, key, value, private_token):
    url = f"https://gitlab.com/api/v4/projects/{project_id}/variables"
    headers = {
        'Content-Type': 'application/json',
        'PRIVATE-TOKEN': private_token
    }
    data = {
        'key': key,
        'value': value
    }
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 201:
        st.success(f'Successfully set variable {key}')
    else:
        st.error(f'Failed to set variable {key}: {response.text}')

# Helper function to trigger GitLab pipeline
import requests
import streamlit as st

def trigger_pipeline(job_type, variables, private_token, project_id):
    url = f"https://{config['DEFAULT_GIT_URL']}/api/v4/projects/{project_id}/trigger/pipeline"

    # Setup the form data
    data = {
        'token': private_token,  # The pipeline trigger token
        'ref': 'main',  # Replace 'main' with the appropriate branch or tag
    }
    
    # Add variables to the form data
    for key, value in variables.items():
        data[f'variables[{key}]'] = value
    
    response = requests.post(url, data=data)
    
    # Debugging output
    st.write(f"Triggering pipeline with URL: {url}")
    st.write(f"Form Data: {data}")
    st.write(f"Response Status Code: {response.status_code}")
    st.write(f"Response Content: {response.content}")
    
    if response.status_code == 201:
        pipeline_url = response.json().get('web_url')
        if pipeline_url:
            st.success(f'{job_type} pipeline triggered successfully! View pipeline at: {pipeline_url}')
        else:
            st.success(f'{job_type} pipeline triggered successfully!')
    else:
        st.error(f"Failed to trigger {job_type} pipeline: {response.text}. Status code: {response.status_code}. Response: {response.json()}")

# Function to load existing variables from the database
def load_existing_variables(job_type):
    c.execute('SELECT * FROM variables WHERE job_type=? ORDER BY id DESC LIMIT 1', (job_type,))
    row = c.fetchone()
    if row:
        return dict(zip([column[0] for column in c.description], row))
    return None

# Password protection
if 'authenticated' not in st.session_state:
    st.session_state.authenticated = False
    st.session_state.AWS_ACCESS_KEY = ""
    st.session_state.AWS_SECRET_KEY = ""

if not st.session_state.authenticated:
    password = st.text_input("Enter Password", type="password")
    if st.button("Submit"):
        if password == config['DEFAULT_PASSWORD']:
            st.session_state.authenticated = True
            st.rerun()
        else:
            st.error("Incorrect password")
else:
    # Collecting input variables from the user
    st.title("GitLab CI/CD Pipeline Trigger")

    job_type = st.selectbox('Select Job Type', ['Deploy VM', 'Internal KCLI OpenShift4 Baremetal', 'External KCLI OpenShift4 Baremetal'])

    existing_variables = load_existing_variables(job_type)

    with st.form(key='pipeline_form'):
        st.text_input("Git Repository", key="GIT_REPO", value=existing_variables['GIT_REPO'] if existing_variables else config['DEFAULT_GIT_REPO'])
        st.text_input("CICD Pipeline", key="CICD_PIPELINE", value=existing_variables['CICD_PIPELINE'] if existing_variables else config['DEFAULT_CICD_PIPELINE'])
        st.text_input("Target Server", key="TARGET_SERVER", value=existing_variables['TARGET_SERVER'] if existing_variables else config['DEFAULT_TARGET_SERVER'])
        st.selectbox("VM Profile", ["freeipa","vyos-router", "rhel8", "rhel9", "openshift-jumpbox", "fedora39", "ubuntu", "centos9stream"], key="VM_PROFILE", index=["freeipa","vyos-router", "rhel8", "rhel9", "openshift-jumpbox", "fedora39", "ubuntu", "centos9stream"].index(existing_variables['VM_PROFILE']) if existing_variables else 0)
        st.text_input("Launch Steps", key="LAUNCH_STEPS", value=existing_variables['LAUNCH_STEPS'] if existing_variables else config['DEFAULT_LAUNCH_STEPS'])
        st.selectbox("Action", ["create", "delete"], key="ACTION", index=0 if existing_variables and existing_variables['ACTION'] == 'create' else 1 if existing_variables and existing_variables['ACTION'] == 'delete' else 0)
        st.selectbox("Community Version", ["true", "false"], key="COMMUNITY_VERSION", index=0 if existing_variables and existing_variables['COMMUNITY_VERSION'] == 'true' else 1 if existing_variables and existing_variables['COMMUNITY_VERSION'] == 'false' else 0)

        if job_type == 'Internal KCLI OpenShift4 Baremetal' or job_type == 'External KCLI OpenShift4 Baremetal':
            st.text_input("Deploy OpenShift", key="DEPLOY_OPENSHIFT", value=existing_variables['DEPLOY_OPENSHIFT'] if existing_variables else config['DEFAULT_DEPLOY_OPENSHIFT'])
            st.text_input("Launch Steps", key="LAUNCH_STEPS", value=existing_variables['LAUNCH_STEPS'] if existing_variables else config['DEFAULT_LAUNCH_STEPS'])
            st.text_input("Tag", key="TAG", value=existing_variables['TAG'] if existing_variables else config['DEFAULT_TAG'])
            st.text_input("Disconnected Install", key="DISCONNECTED_INSTALL", value=existing_variables['DISCONNECTED_INSTALL'] if existing_variables else config['DEFAULT_DISCONNECTED_INSTALL'])
            st.text_input("Deployment Config", key="DEPLOYMENT_CONFIG", value=existing_variables['DEPLOYMENT_CONFIG'] if existing_variables else config['DEFAULT_DEPLOYMENT_CONFIG'])

        if job_type == 'External KCLI OpenShift4 Baremetal':
            st.text_input("GUID", key="GUID", value=existing_variables['GUID'] if existing_variables else config['DEFAULT_GUID'])
            st.text_input("IP Address", key="IP_ADDRESS", value=existing_variables['IP_ADDRESS'] if existing_variables else config['DEFAULT_IP_ADDRESS'])
            st.text_input("Zone Name", key="ZONE_NAME", value=existing_variables['ZONE_NAME'] if existing_variables else config['DEFAULT_ZONE_NAME'])
            st.text_input("AWS Access Key (Stored in GitLab Variables)", key="AWS_ACCESS_KEY", type="password")
            st.text_input("AWS Secret Key (Stored in GitLab Variables)", key="AWS_SECRET_KEY", type="password")
            st.text_input("Verbose Level", key="VERBOSE_LEVEL", value=existing_variables['VERBOSE_LEVEL'] if existing_variables else config['DEFAULT_VERBOSE_LEVEL'])

        private_token = st.text_input("GitLab Private Token", type="password", value=config['DEFAULT_PRIVATE_TOKEN'])
        project_id = st.text_input("GitLab Project ID", value=config['DEFAULT_PROJECT_ID'])

        submit_button = st.form_submit_button(label='Trigger Pipeline')

    if submit_button:
        variables = {
            'ref': config['DEFAULT_REF'],  # Add the ref here
            'CI_PIPELINE_SOURCE': 'trigger',  # Add CI_PIPELINE_SOURCE as 'trigger'
            'GIT_REPO': st.session_state.GIT_REPO,
            'CICD_PIPELINE': st.session_state.CICD_PIPELINE,
            'TARGET_SERVER': st.session_state.TARGET_SERVER,
            'VM_PROFILE': st.session_state.VM_PROFILE,
            'ACTION': st.session_state.ACTION,
            'COMMUNITY_VERSION': st.session_state.COMMUNITY_VERSION
        }

        if job_type == 'Deploy VM':
            variables.update({
                'LAUNCH_STEPS': st.session_state.LAUNCH_STEPS
            })
        if job_type == 'Internal KCLI OpenShift4 Baremetal' or job_type == 'External KCLI OpenShift4 Baremetal':
            variables.update({
                'DEPLOY_OPENSHIFT': st.session_state.DEPLOY_OPENSHIFT,
                'LAUNCH_STEPS': st.session_state.LAUNCH_STEPS,
                'TAG': st.session_state.TAG,
                'DISCONNECTED_INSTALL': st.session_state.DISCONNECTED_INSTALL,
                'DEPLOYMENT_CONFIG': st.session_state.DEPLOYMENT_CONFIG
            })

        if job_type == 'External KCLI OpenShift4 Baremetal':
            variables.update({
                'GUID': st.session_state.GUID,
                'IP_ADDRESS': st.session_state.IP_ADDRESS,
                'ZONE_NAME': st.session_state.ZONE_NAME,
                'VERBOSE_LEVEL': st.session_state.VERBOSE_LEVEL
            })

        # Store secrets as GitLab CI/CD variables
        set_gitlab_variable(project_id, "AWS_ACCESS_KEY", st.session_state.AWS_ACCESS_KEY, private_token)
        set_gitlab_variable(project_id, "AWS_SECRET_KEY", st.session_state.AWS_SECRET_KEY, private_token)

        variables['job_type'] = job_type

        # Store other variables in SQLite
        c.execute('''
            INSERT INTO variables (job_type, GIT_REPO, CICD_PIPELINE, TARGET_SERVER, VM_PROFILE, ACTION, COMMUNITY_VERSION, 
            DEPLOY_OPENSHIFT, LAUNCH_STEPS, TAG, DISCONNECTED_INSTALL, DEPLOYMENT_CONFIG, GUID, IP_ADDRESS, ZONE_NAME, VERBOSE_LEVEL, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (variables['job_type'], variables['GIT_REPO'], variables['CICD_PIPELINE'], variables['TARGET_SERVER'], variables['VM_PROFILE'], 
              variables['ACTION'], variables['COMMUNITY_VERSION'], variables.get('DEPLOY_OPENSHIFT'), variables.get('LAUNCH_STEPS'), 
              variables.get('TAG'), variables.get('DISCONNECTED_INSTALL'), variables.get('DEPLOYMENT_CONFIG'), variables.get('GUID'), 
              variables.get('IP_ADDRESS'), variables.get('ZONE_NAME'), variables.get('VERBOSE_LEVEL'), 'started'))
        conn.commit()

        st.success(f'{job_type} pipeline variables stored successfully!')

        # Trigger the pipeline
        trigger_pipeline(job_type, variables, private_token, project_id)

    # Display stored variables
    st.subheader('Stored Variables')
    c.execute('SELECT * FROM variables')
    rows = c.fetchall()
    st.table(rows)

    if st.button("Clear Database"):
        c.execute('DELETE FROM variables')
        conn.commit()
        st.success("Database cleared successfully!")
