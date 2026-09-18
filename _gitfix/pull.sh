cd "D:/new bee"
git -c http.proxy=http://127.0.0.1:63133 \
    -c http.version=HTTP/1.1 \
    -c http.postBuffer=524288000 \
    fetch-pack --stdin --all https://github.com/3311930677/new-bee.git < _gitfix/want_objects.txt
