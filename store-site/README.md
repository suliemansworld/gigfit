# Echo Cave public information site

The official public privacy, support, and pre-release accessibility pages for Echo Cave on iPhone.

## Routes

- `/` — product introduction
- `/privacy` — App Store privacy-policy URL
- `/support` — App Store support URL and contact information
- `/accessibility` — accessibility approach, scope, and feedback

The site has no account, analytics, advertising, forms, cookies, database, or application-owned tracking. Support is provided through a user-initiated email link.

## Development

Requires Node.js 22.13 or later.

```bash
npm install
npm run dev
npm test
```

`npm test` creates the production build and verifies that all four routes render their expected policy content.
