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

async function run() {
  const [,, localFile, title, category, profileHandle, priceEuros, condition, tagsStr, description] = process.argv;

  const ext = path.extname(localFile).slice(1) || 'jpg';
  const key = `${category || 'listings'}/ai-generated/${Date.now()}.${ext}`;
  await r2.send(new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
    Body: fs.readFileSync(localFile),
    ContentType: `image/${ext === 'jpg' ? 'jpeg' : ext}`,
  }));
  const publicUrl = `${process.env.NEXT_PUBLIC_R2_PUBLIC_URL}/${key}`;
  console.log(`Uploaded: ${publicUrl}`);

  const { data: profile } = await supabase.from('profiles').select('id').eq('handle', profileHandle).single();
  if (!profile) { console.error('Profile not found:', profileHandle); return; }

  const tags = tagsStr ? tagsStr.split(',') : [];
  const { data: listing, error } = await supabase.from('listings').insert({
    title,
    description: description || `Handmade ${title.toLowerCase()}, unique piece.`,
    category: category || 'accessories',
    condition: condition || 'new',
    price: Math.round(Number(priceEuros) * 100),
    profile_id: profile.id,
    images: [publicUrl],
    tags,
    ships_to: ['WORLDWIDE'],
    size: 'One Size',
    status: 'active',
  }).select('id').single();

  if (error) console.error('Error:', error.message);
  else console.log(`Created listing: ${title} (${listing.id})`);
}
run().catch(console.error);
