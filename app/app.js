var express = require('express');
const https = require("https"),
fs = require("fs");

console.log('Example tls app start!');
console.log('read the secret :'+process.env.GREETING)

const kyeFilePath = '/tls/key.pem';
const certFilePath = '/tls/cert.pem';


try {
  fs.readFile(kyeFilePath, 'utf8', function (err,data) {
    if (err) {
      return console.log('err: '+err);
    }
    console.log('key.pem read');
  });
} catch(err) {
  console.log('error='+err);
}

try {
  fs.readFile(certFilePath, 'utf8', function (err,data) {
    if (err) {
      return console.log('err: '+err);
    }
    console.log('cert read');
  });
} catch(err) {
  console.log('error='+err);
}

var app = express();
app.get('/', function (req, res) {
  console.log('scone mode is :'+process.env.GREETING)
  res.send('Hello World!' + process.env.GREETING);
});

app.listen(443, function () {
  console.log('Example tls app listening on port 443!');
  console.log('scone mode is :'+process.env.GREETING)
  console.log('Ok.');
});


