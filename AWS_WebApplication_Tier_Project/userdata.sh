#!/bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo chkconfig httpd on
sudo service httpd start
echo "<h1>Application Webteir Deployed By DheerajTechInsight Youtube Tutorial</h1>" | sudo tee /var/www/html/index.html
sudo yum install -y https://s3.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
