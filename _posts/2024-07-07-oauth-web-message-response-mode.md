---
layout: post
slug: oauth-web-message-response-mode
redirect_from:
  - /blog/oauth-web-message-response-mode/
---


I recently came across an interesting variation of an OAuth / OpenId Connect authentication flow: OAuth Authentication via a Popup.


In this flow, the client application opens a popup window showing the login form of the authorization server. 
After the user logs in successfully, the popup window closes and the client application in the parent window receives the user id.
How does this work?

As we will see, this flow makes use of the web message response mode of OAuth, which relies on the post message web API.

The protocol is [currently a draft](https://www.ietf.org/archive/id/draft-meyerzuselha-oauth-web-message-response-mode-00.html) - I can recommend reading through the standard since it explains it probably better than I am going to do.


Let's dive into these two topics and see how it works: 

1. Post message web API..
2. ... and how it is used in web message OAuth response mode

---


## Sending data between different browser windows with post message


In a nutshell, the post message web API allows you to send and receive data between different browser windows.

[MDN has great documentation about post message](https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage)

I think this is best understood with an example:

For our little demo we need two pages: The `parent.html` page, and the popup `child.html`.

First the `parent.html` page opens the popup and registers an event listener for the `message` event:
```
window.open('child.html', 'childWindow', 'width=600,height=400');

// Listen for messages from the child window
window.addEventListener('message', (event) => {
    console.log("Message", event?.data)
});
```

Then, the `child.html` obtains a reference to the parent window, and uses the `postMessage` method on it to send it: 

```
// obtain a reference to the parent window
const windowRef = window.opener
windowRef.postMessage({message: "Hello from child page!"}, window.location.origin);
```


Now that we understand how to send and receive data through post message, we can see how OAuth makes use of it.


## Web message response mode in OAuth

The [OAuth Authorization Code Flow describes](https://auth0.com/docs/get-started/authentication-and-authorization-flow/authorization-code-flow) how the client application receives an authorization code that then is exchanged for a token.

In the "normal" case, the authorization server redirects the user back to the redirect_uri and attaches the code as a query parameter in the redirect_uri.
This is the `query` response mode. (The `fragment` response mode attaches the code as part of the [URL fragment](https://en.wikipedia.org/wiki/URI_fragment), so after the hash symbol `#`.)

In contrast, `web_message` response mode returns the authorization code as a message via the post message interface.

To test this, we can create a little demo that opens the authorization url of our OAuth identity server via window.open as a popup, and then starts to listen for the code as a `message` event.

```
const authorizeUrl = `https://my-idp.com/authorize?response_type=code&response_mode=web_message...` 

window.open(authorizeUrl, 'childWindow', 'width=600,height=400');

// Listen for messages from the child window
window.addEventListener('message', (event) => {
    console.log("Message", event?.data)
});
```

This is exactly what we did before in our example about post message.

The flow will now be like this: 

- Our application opens the popup with the link to the authorization server.
- Our application will start listening to the post message event.
- The user authenticates in the popup.
- The authorization sends the authorization code back to our application via the post message event.
- Our application receives the authorization code and exchanges it for the access and id token.

There are a couple of demo applications out there for debugging OAuth auth servers. 

- For example, the [OAuth Playground](https://www.oauth.com/playground/authorization-code.html) is really useful for understanding the basics behind OAuth and different OAuth flows. 
- Or [OAuth Debugger](https://oauthdebugger.com/])

But I could not find one that supported the `web_message` response mode, so I build my own:

[https://githubjakob.github.io/oauth-web-message-debugger/](https://githubjakob.github.io/oauth-web-message-debugger/)

## Support

The response mode described in this article [is supported by Auth0](https://auth0.com/docs/authenticate/protocols/oauth).

We can see that Auth0 SDK `auth0-spa-js` is implementing the same logic that we implemented in the demo.

First building the authorization url using `response_mode=web_message`

```
const params = await this._prepareAuthorizeUrl(
      options.authorizationParams || {},
      { response_mode: 'web_message' },
      window.location.origin
    );
```
Source [https://github.com/auth0/auth0-spa-js/blob/main/src/Auth0Client.ts#L372C7-L372C40](https://github.com/auth0/auth0-spa-js/blob/main/src/Auth0Client.ts#L372C7-L372C40)


Then setting up the event listener for the message event:
```
window.addEventListener('message', popupEventListener);
```
Source: [https://github.com/auth0/auth0-spa-js/blob/main/src/utils.ts#L136](https://github.com/auth0/auth0-spa-js/blob/main/src/utils.ts#L136)

Octa has a similar `okta_post_message` response mode, and while I did not test it, I assume it works similiar: https://developer.okta.com/docs/reference/api/oidc/


---





