#!/bin/bash

set -e

# Tell apt to read from the ROS package repository
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu jessie main" > /etc/apt/sources.list.d/ros-latest.list'
wget https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -O - | sudo apt-key add -

# Update apt
sudo apt-get update
sudo apt-get -y upgrade

# Install dependencies
sudo apt-get install python-pip
sudo pip install rosdep rosinstall_generator wstool

# Initialize rosdep
if [ -f /etc/ros/rosdep/sources.list.d/20-default.list ];
    then sudo rm /etc/ros/rosdep/sources.list.d/20-default.list
fi
sudo rosdep init
rosdep update

# Create a service
sudo cp ./run.sh /opt/openag_run.
sudo cp ./openag.service /lib/systemd/system/openag.service

# Create a catkin workspace
mkdir -p ~/ros_catkin_ws
cd ~/ros_catkin_ws

# Install ros_comm and rosserial
echo Generating rosinstall file...
rm -f indigo.rosinstall src/.rosinstall
rosinstall_generator ros_comm rosserial rosserial_arduino --rosdistro indigo --deps --wet-only --exclude roslisp --tar > indigo.rosinstall
wstool init src indigo.rosinstall

# Install dependencies for all installed packages
rosdep install --from-paths src --ignore-src --rosdistro indigo -y -r --os=debian:jessie

# Install packages in system directory
sudo ./src/catkin/bin/catkin_make_isolated --install -DCMAKE_BUILD_TYPE=Release --install-space /opt/ros/indigo -j2

# Activate the ROS environment
source /opt/ros/indigo/setup.bash
echo "source /opt/ros/indigo/setup.bash" >> ~/.bashrc

# Install couchdb
sudo apt-get install -y couchdb

# Download  and install core openag python package
mkdir -p ~/openag/src
cd ~/openag/src
if [ -x openag_python ]; then
    cd openag_python
    git pull
else
    git clone https://github.com/OpenAgInitiative/openag_python.git
    cd openag_python
fi
sudo pip install -e .

# Create a catkin workspace to work in and install openag_brain in it
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws/src
if [ ! -f ./CMakeLists.txt ]; then
    catkin_init_workspace
fi
if [ -x openag_brain ]; then
    cd openag_brain
    git pull
else
    git clone https://github.com/OpenAgInitiative/openag_brain.git
fi
cd ~/catkin_ws
catkin_make
catkin_make install
source devel/setup.bash
rosdep install -i -y openag_brain || exit 1

rosrun openag_brain install_pio
