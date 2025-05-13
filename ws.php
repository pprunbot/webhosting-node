<?php
// 设置代理地址为本地 Node.js 服务
$target = '127.0.0.1:$PORT';

$method = $_SERVER['REQUEST_METHOD'];
$headers = getallheaders();
$body = file_get_contents('php://input');

// 打开 socket 连接
$fp = stream_socket_client("tcp://$target", $errno, $errstr, 30);
if (!$fp) {
    header("HTTP/1.1 502 Bad Gateway");
    echo "Connection failed: $errstr ($errno)";
    exit;
}

// 发送 HTTP 请求头
fwrite($fp, "$method {$_SERVER['REQUEST_URI']} HTTP/1.1\r\n");
foreach ($headers as $key => $value) {
    fwrite($fp, "$key: $value\r\n");
}
fwrite($fp, "\r\n$body");

// 将响应输出
while (!feof($fp)) {
    echo fgets($fp, 4096);
}

fclose($fp);
?>
