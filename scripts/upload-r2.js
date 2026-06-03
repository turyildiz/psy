const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

require('fs').readFileSync('.env.local', 'utf8').split('\n').forEach(l => {
  const [k, v] = l.split('=');
  if (k && v) process.env[k.trim()] = v.trim();
});

const r2 = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function uploadAndAssign(localFile, folder, listingTitle) {
  const ext = path.extname(localFile).slice(1) || 'jpg';
  const key = `${folder}/ai-generated/${Date.now()}.${ext}`;
  const body = fs.readFileSync(localFile);

  await r2.send(new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
    Body: body,
    ContentType: `image/${ext === 'jpg' ? 'jpeg' : ext}`,
  }));

  const publicUrl = `${process.env.NEXT_PUBLIC_R2_PUBLIC_URL}/${key}`;
  console.log(`Uploaded: ${publicUrl}`);

  if (listingTitle) {
    const { data: listing } = await supabase.from('listings').select('id, images').eq('title', listingTitle).single();
    if (listing) {
      const newImages = [publicUrl, ...(listing.images || []).slice(0, 2)];
      await supabase.from('listings').update({ images: newImages }).eq('id', listing.id);
      console.log(`Assigned to listing: ${listingTitle}`);
    }
  }

  return publicUrl;
}

// Args: node upload-r2.js <localFile> <folder> <listingTitle>
const [,, localFile, folder, ...titleParts] = process.argv;
const listingTitle = titleParts.join(' ');
uploadAndAssign(localFile, folder || 'listings', listingTitle || null).catch(console.error);
