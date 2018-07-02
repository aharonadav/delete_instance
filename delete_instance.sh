#!/bin/bash

REGION=$1
PROFILE=$2
INSTANCE=$3

#Get volume ID
VOLUMELIST= /usr/local/bin/aws ec2 describe-instances --instance-ids $INSTANCE  --query Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId --output text --profile $PROFILE --region $REGION | tr "\t" "\n" > /tmp/volumelist.txt

echo "Powering off Instance $INSTANCE"
/usr/local/bin/aws ec2 stop-instances --instance-id $INSTANCE --profile $PROFILE --region $REGION
INSTANCE_STATE=`/usr/local/bin/aws ec2 describe-instances --instance-id $INSTANCE --query Reservations[].Instances[].State.Name --output text --profile $PROFILE --region $REGION`

printf "Please wait.\n"

while [[ "$INSTANCE_STATE" != "stopped" ]]
do
  sleep 4
  echo "."
  INSTANCE_STATE=`/usr/local/bin/aws ec2 describe-instances --instance-id $INSTANCE --query Reservations[].Instances[].State.Name --output text --profile $PROFILE --region $REGION`
done

#Check status volume ID (In-use / Available)
for VOL in $(cat volumelist.txt);
do
  #Get Instance ID for volume.
  INSTANCE_ID=`/usr/local/bin/aws ec2 describe-volumes --volume-ids $VOL --query Volumes[].Attachments[].InstanceId --profile $PROFILE --region $REGION --output text`

  #Check if volume defined as "Delete on termination".
  DELETE_ON_TERMINATION= /usr/local/bin/aws ec2 describe-volumes --volume-ids $VOL --query Volumes[].Attachments[].DeleteOnTermination --profile $PROFILE --region $REGION --output text | grep False

  printf "Volume $VOL, is attached to Instance ID: $INSTANCE_ID\n. "
  INUSE= /usr/local/bin/aws ec2 describe-volumes --volume-ids $VOL --profile $PROFILE --region $REGION --query 'Volumes[].State' --output text | grep "in-use"

  if [ $? -eq 0 ];then
    /usr/local/bin/aws ec2 detach-volume --volume-id $VOL --profile $PROFILE --region $REGION
    INUSE=`/usr/local/bin/aws ec2 describe-volumes --volume-ids $VOL --profile $PROFILE --region $REGION --query 'Volumes[].State' --output text`
    while [[ "$INUSE" != "available" ]]
    do
      sleep 2
      echo "."
      INUSE=`aws ec2 describe-volumes --volume-ids $VOL --profile $PROFILE --region $REGION --query 'Volumes[].State' --output text`
    done

    /usr/local/bin/aws ec2 delete-volume --volume-id $VOL --profile $PROFILE --region $REGION
  else
    exit
    /usr/local/bin/aws ec2 delete-volume --volume-id $VOL --profile $PROFILE --region $REGION
  fi

done


echo "\nTerminating instance $INSTANCE_ID . . ."
/usr/local/bin/aws ec2 terminate-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION

while [[ "$INSTANCE_STATE" != "terminated" ]]
do
  INSTANCE_STATE=`/usr/local/bin/aws ec2 describe-instances --instance-id $INSTANCE --query Reservations[].Instances[].State.Name --output text --profile $PROFILE --region $REGION`
done

printf "\n\n#####  Done  #####"
