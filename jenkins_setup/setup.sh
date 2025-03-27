#!/bin/bash

export JENKINS_HOME=$HOME/dev/jenkins
nohup java -jar /home/javad/dev/jenkins_setup/jenkins.war --httpPort=32769 > jenkins.log 2>&1 &  
echo $! > jenkins.pid
