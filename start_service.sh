docker build -t fable_projects/dnd_flutter:latest .
docker stop dnd_flutter
docker rm dnd_flutter
docker run -d --name dnd_flutter -p 80:80 fable_projects/dnd_flutter:latest
dns-sd -P dnd _java._tcp local 8080 dnd.local $(ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d\  -f2) &
dns-sd -P dnd . local 80 dnd.local $(ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d\  -f2) &
