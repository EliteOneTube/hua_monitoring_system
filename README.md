# MAKE SURE TO INSTALL DOCKER FROM DOCKER WEBSITE SINCE SNAP INSTALL DOESNT HAVE ENOUGH PRIVELEGES

# Follow https://blog.ptidej.net/using-powerapi-to-measure-the-energy-consumption-of-your-device/

# OID for total octets received 1.3.6.1.2.1.2.2.1.10 https://oid-base.com/cgi-bin/display?oid=1.3.6.1.2.1.2.2.1.10&a=display



curl -v -X POST http://10.100.106.227:8080/api/v1/N9laGGgjjF28VA3nTyTa/telemetry --header Content-Type:application/json --data "{temperature:25}"