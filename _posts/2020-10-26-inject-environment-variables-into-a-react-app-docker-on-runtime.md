---
layout: post
slug: inject-environment-variables-into-a-react-app-docker-on-runtime
redirect_from:
  - /blog/inject-environment-variables-into-a-react-app-docker-on-runtime/
---



In this blog post I want to show you how you can inject environment variables into a React application.

---

Separating config from code is a good practice[^1] for designing applications. For example you need to add config to your front end application, when you have it deployed in different environments, e.g. a staging and a production environment.

Baking the configuration into the code or the Docker image both violates the principle of separating config from code.

The solution is to pass as environment variables, e.g. the API URL of the back end, to React when the Docker container starts up.

But since a React application is just bundled static HTML/JavaScript/CSS, your front end cannot directly pick up the environment variables available on the server side!

This blog post shows you how you nonetheless can do it:

## Inject environment variables into a React application on runtime

The Create React App documentation gives a hint[^2] how to inject configuration into a React application: On the server side, you can set global variables on the window object inside your HTML.

Here is a step-by-step guide of how what you need to do:

Firstly, you set the required environment variables on the window object. To do that create a JavaScript file called env_vars.js:

```
window.API_URL = "localhost:8080";
```

Secondly, the env_vars.js JavaScript is embedded in the HTML of your front end application:

```
<!DOCTYPE html>
<html lang="en">

<head>
<script type="text/javascript" src="env_vars.js"></script>
```

Next, you add a bash script that picks up the environment variables and writes them to the env_vars.js file. After that the bash script it starts to serve the front end.

```
cat <<EOF > /usr/src/app/build/env_vars.js
window.API_URL="$API_URL";
EOF

serve -s ./build/ -l 8080
```

Finally, set the Dockerfile’s entry point to the bash script:


```
RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["/usr/src/app/docker-entrypoint.sh"]
```

That’s it!

The environment variables inside the Docker container are now made available to the JavaScript running on the client side.

## Run it in Docker

Now when you start up the Docker container, you can pass a environment variable to React:

```
docker run -e API_URL=test.myapp.com docker-inject-env-react-runtime
```

## GitHub of the Demo project

I created a Demo project on GitHub that contains a working example.[^3]

---
{: data-content="footnotes"}

[^1]: [https://12factor.net/config](https://12factor.net/config)
[^2]: [https://create-react-app.dev/docs/title-and-meta-tags/#injecting-data-from-the-server-into-the-page](https://create-react-app.dev/docs/title-and-meta-tags/#injecting-data-from-the-server-into-the-page)
[^3]: [https://github.com/githubjakob/react-inject-env-docker-runtime](https://github.com/githubjakob/react-inject-env-docker-runtime)