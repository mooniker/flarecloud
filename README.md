# Script to Update Dynamic DNS with CloudFlare

```sh
./ddns.sh update cloudflare \
    --interactive \
    --verbose # optionally, prints out play by play
```

You may pass config values as args.

```sh
./ddns.sh update cloudflare \
    --verbose # optionally, prints out play by play
    --record-set-name my.domain.com \
    --hosted-zone-id 70lbmzqg8yjcqhadg89aij7w0p7iz2ff \
    --auth-token qN8fSQcQURy5RhD8uZ4b75CJo237cmVOgESV1NOx \
    --record-id so28rwjeywz142q2c9oe0hw2feprcs70
```

You'll need to supply your own
- record set name,
- API token (provisioned on the [acct profile](https://dash.cloudflare.com/profile/api-tokens)), and
- record id ([looked up using an API key](https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records)).
