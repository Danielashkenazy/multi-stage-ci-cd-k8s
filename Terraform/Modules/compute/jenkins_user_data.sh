#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting Jenkins automated installation..."

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install Java 17
apt-get install -y openjdk-17-jdk curl wget jq python3-pip

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins (but don't start it yet)
apt-get update
apt-get install -y jenkins

# Stop Jenkins if it auto-started
systemctl stop jenkins || true

# Install Docker
apt-get install -y apt-transport-https ca-certificates software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker jenkins

# Install AWS CLI
apt-get install -y awscli

echo "=== Creating Jenkins configuration BEFORE first start ==="

# Configure Jenkins to skip setup wizard
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
Environment="JENKINS_OPTS=--httpPort=8080 --httpListenAddress=0.0.0.0"
EOF

systemctl daemon-reload

# Create Jenkins home directory structure
mkdir -p /var/lib/jenkins/init.groovy.d
mkdir -p /var/lib/jenkins/users/admin

# -------------------------------
# 01 - Basic security setup
# -------------------------------
cat > /var/lib/jenkins/init.groovy.d/01-basic-security.groovy <<'GROOVYEOF'
#!groovy
import jenkins.model.*
import hudson.security.*
import jenkins.install.InstallState

def instance = Jenkins.getInstance()

println "--> Creating local admin user"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('admin', 'Admin123!')
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()

println "--> Configuration complete. Setup wizard disabled."
GROOVYEOF


# -------------------------------
# 02 - Plugin installation
# -------------------------------
cat > /var/lib/jenkins/init.groovy.d/02-install-plugins.groovy <<'GROOVYEOF'
#!groovy
import jenkins.model.*

def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()

println "--> Updating plugin list"
uc.updateAllSites()

def maxRetries = 60
def retry = 0
while(uc.getSites().any { it.getPlugin("git") == null } && retry < maxRetries) {
    println "--> Waiting for update center... (${retry}/${maxRetries})"
    sleep(1000)
    retry++
}

def plugins = [
    "git",
    "workflow-aggregator",
    "docker-workflow",
    "pipeline-stage-view", 
    "credentials-binding",
    "amazon-ecr",
    "blueocean"
]

def needRestart = false

plugins.each { pluginName ->
    if (!pm.getPlugin(pluginName)) {
        println "--> Installing plugin: ${pluginName}"
        def plugin = uc.getPlugin(pluginName)
        if (plugin) {
            plugin.deploy(true)
            needRestart = true
        } else {
            println "--> WARNING: Plugin not found: ${pluginName}"
        }
    } else {
        println "--> Plugin already installed: ${pluginName}"
    }
}

instance.save()

if (needRestart) {
    println "--> Plugins installed. Restart required."
}
GROOVYEOF


# -------------------------------
# 03 - Create JNLP agent node
# -------------------------------
cat > /var/lib/jenkins/init.groovy.d/03-create-agent-node.groovy <<'GROOVYEOF'
#!groovy
import jenkins.model.*
import hudson.model.*
import hudson.slaves.*

def instance = Jenkins.getInstance()

sleep(10000)

println "--> Creating JNLP agent node"

def nodeName = "app-agent"
def nodeDescription = "App EC2 Agent Node"
def remoteFS = "/home/ubuntu/jenkins"
def numExecutors = 1
def labelString = "app ec2-agent"
def mode = Node.Mode.NORMAL

def existingNode = instance.getNode(nodeName)
if (existingNode != null) {
    println "--> Agent '${nodeName}' already exists, skipping"
    return
}

def launcher = new JNLPLauncher()
def agent = new DumbSlave(nodeName, remoteFS, launcher)

agent.setNodeDescription(nodeDescription)
agent.setNumExecutors(numExecutors)
agent.setLabelString(labelString)
agent.setMode(mode)
agent.setRetentionStrategy(new RetentionStrategy.Always())

instance.addNode(agent)
instance.save()

println "--> Agent '${nodeName}' created successfully"
GROOVYEOF


# -------------------------------
# 04 - Set Jenkins URL (private IP)
# -------------------------------
cat > /var/lib/jenkins/init.groovy.d/04-set-url.groovy <<'GROOVYEOF'
import jenkins.model.*
import java.net.URL

def privateIp = "http://" + new URL("http://169.254.169.254/latest/meta-data/local-ipv4").text + ":8080/"

println "--> Setting Jenkins URL to: ${privateIp}"

def jlc = JenkinsLocationConfiguration.get()
jlc.setUrl(privateIp)
jlc.setAdminAddress("admin@local")
jlc.save()

println "--> Jenkins URL set successfully"
GROOVYEOF


# Apply permissions
chown -R jenkins:jenkins /var/lib/jenkins
chmod 644 /var/lib/jenkins/init.groovy.d/*.groovy


# Start Jenkins
echo "=== Starting Jenkins with pre-configured settings ==="
systemctl enable jenkins
systemctl start jenkins

echo "Waiting for Jenkins to start..."
sleep 30

until curl -s http://localhost:8080 > /dev/null 2>&1; do
    echo "Still waiting for Jenkins..."
    sleep 10
done

sleep 60

echo "Username: admin"
echo "Password: Admin123!"
echo "=========================================="
echo "Agent 'app-agent' is waiting for connection"
echo "=========================================="

echo "Creating AWS env vars..."
echo 'export ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)' >> ~/.bashrc
source ~/.bashrc
echo 'export PATH=$PATH:/var/lib/jenkins/.local/bin' >> /var/lib/jenkins/.bashrc
source /var/lib/jenkins/.bashrc

sudo chown -R jenkins:jenkins /var/lib/jenkins/workspace/
sudo chmod -R 755 /var/lib/jenkins/workspace/

