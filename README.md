# opengrok-alpine

"one-time" OpenGrok Docker image, based on Alpine Linux.

Put src.tar.gz including the source codes.

```
src.tar.gz
  |- project1/
      |- ...
  |- project2/
      |- ...
```

And then, `docker build . -t your-opengrok` for build, and `docker run --rm -p 8080:8080 your-opengrok`.
