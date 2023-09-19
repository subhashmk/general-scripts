yyyymmdd=`date +%Y%m%d`
isoDate=`date --utc +%Y%m%dT%H%M%SZ`

# EDIT: Change value of these four variables to match your account
s3Bucket="my_bucket_name"
bucketLocation="eu-central-1" 
s3AccessKey="thisismyaccesskey123"
s3SecretKey="thisismysecretkeyabcd1234efgh5678"

fileToUpload="/complete/path/of/file"
objectKey="file_name" # This is file name in AWS S3 bucket

endpoint="s3-${bucketLocation}.amazonaws.com"

contentLength=`cat ${fileToUpload} | wc -c`
contentHash=`openssl sha256 -hex ${fileToUpload} | sed 's/.* //'`
contentMD5hash=`openssl dgst -binary -md5 < ${fileToUpload} | openssl enc -base64`

canonicalRequest="PUT\n/${s3Bucket}/${objectKey}\n\ncontent-length:${contentLength}\nhost:${endpoint}\nx-amz-content-sha256:${contentHash}\nx-amz-date:${isoDate}\n\ncontent-length;host;x-amz-content-sha256;x-amz-date\n${contentHash}"
canonicalRequestHash=`echo -en ${canonicalRequest} | openssl sha256 -hex | sed 's/.* //'`

stringToSign="AWS4-HMAC-SHA256\n${isoDate}\n${yyyymmdd}/${bucketLocation}/s3/aws4_request\n${canonicalRequestHash}"

echo "----------------- canonicalRequest --------------------"
echo -e ${canonicalRequest}
echo "----------------- stringToSign --------------------"
echo -e ${stringToSign}
echo "-------------------------------------------------------"

# calculate the signing key
DateKey=`echo -n "${yyyymmdd}" | openssl sha256 -hex -hmac "AWS4${s3SecretKey}" | sed 's/.* //'`
DateRegionKey=`echo -n "${bucketLocation}" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateKey} | sed 's/.* //'`
DateRegionServiceKey=`echo -n "s3" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateRegionKey} | sed 's/.* //'`
SigningKey=`echo -n "aws4_request" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateRegionServiceKey} | sed 's/.* //'`
# then, once more a HMAC for the signature
signature=`echo -en ${stringToSign} | openssl sha256 -hex -mac HMAC -macopt hexkey:${SigningKey} | sed 's/.* //'`

authorization="Authorization: AWS4-HMAC-SHA256 Credential=${s3AccessKey}/${yyyymmdd}/${bucketLocation}/s3/aws4_request, SignedHeaders=content-length;host;x-amz-content-sha256;x-amz-date, Signature=${signature}"

curl -v -X PUT -T "${fileToUpload}" \
-H "Host: ${endpoint}" \
-H "Content-Length: ${contentLength}" \
-H "Content-MD5: ${contentMD5hash}" \
-H "x-amz-date: ${isoDate}" \
-H "x-amz-content-sha256: ${contentHash}" \
-H "${authorization}" \
http://${endpoint}/${s3Bucket}/${objectKey}