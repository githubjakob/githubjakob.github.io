---
layout: post
slug: inject-environment-variables-into-a-react-app-docker-on-runtime
redirect_from:
  - /blog/inject-environment-variables-into-a-react-app-docker-on-runtime/
---


I recently came across an interesting variation of an OAuth / OpenId Connect authentication flow: OAuth Authentication via a Popup.


In this flow, the client application opens a popup window showing the login form of the authorization server. 
After the user logs in successfully, the popup window closes and the client application in the parent window receives the user id.
How does this work?

As we will see, this flow makes use of the web message response mode of OAuth, which relies on the post message web API.

The protocol is currently a draft
https://www.ietf.org/archive/id/draft-meyerzuselha-oauth-web-message-response-mode-00.html



Let's dive into these two topics and see how it works.


## Post Message


In a nutshell, the post message web API allows you to send and receive data between different browser windows.

MDN has great documentation about 
https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage 




I think this is best understood with an example:

For our little demo we need two pages: The `parent.html` page, and the popup `child.html`.

First the `parent.html` page opens the popup and registers an event listener for the 'message' event:
```
window.open('child.html', 'childWindow', 'width=600,height=400');

// Listen for messages from the child window
window.addEventListener('message', (event) => {
    console.log("Message", event?.data)
});
```



```
// obtain a reference to the parent window
const windowRef = window.opener
windowRef.postMessage({message: "Hello from child page!"}, window.location.origin);
```

// TODO add full working example


https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage

Now that we understand how to send and receive data through post message, we can see how OAuth makes use of it.


## Web message response mode in OAuth

The OAuth Authorization Code Flow 

https://www.oauth.com/playground/authorization-code.html

Probably the 
`query` response mode returns the authorization code as a query parameter in the redirect to the `redirect_url`.

In contrast, `web_message` response mode returns the authorization code as a message via the post message interface.

To test this, we can create a little demo that opens the authorize url of our OAuth identity server via window.open as a popup
and starts to listen for the code as a `message` event.

```
const authorizeUrl = `https://my-idp.com/authorize?response_type=code&response_mode=web_message...` 
```

The flow will now be like this: 

- Our application opens the popup with the link to the authorization server.
- Our application will start listening to the post message event.
- The user authenticates in the popup.
- The authorization sends the authorization code back to our application via the post message event.
- Our application receives the authorization code and exchanges it for the access and id token.


There are a couple of demo applications out there for debugging OAuth auth servers (e.g. https://oauthdebugger.com/), but I could not find one that supported the `web_message` response mode, so I build my own:

https://githubjakob.github.io/oauth-web-message-debugger/





## Support


The response mode described in this article is supported by Auth0

https://auth0.com/docs/authenticate/protocols/oauth



What I described in the example is also more or less what their SDK `auth0-spa-js` does.


https://github.com/auth0/auth0-spa-js/blob/main/src/Auth0Client.ts#L372C7-L372C40

Octa has a similar `okta_post_message` response mode, and while I did not test it, I assume it works similiar: https://developer.okta.com/docs/reference/api/oidc/






