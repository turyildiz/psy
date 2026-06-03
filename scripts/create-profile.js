const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');
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
  const [,, avatarFile, handle, displayName, type, location, bio, instagram] = process.argv;

  // Upload avatar to R2
  const key = `avatars/ai-generated/${Date.now()}.jpg`;
  await r2.send(new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
    Body: fs.readFileSync(avatarFile),
    ContentType: 'image/jpeg',
  }));
  const avatarUrl = `${process.env.NEXT_PUBLIC_R2_PUBLIC_URL}/${key}`;
  console.log(`Avatar: ${avatarUrl}`);

  // Create a phantom auth user so we can have a user_id
  const fakeEmail = `${handle}@psy.market.demo`;
  const { data: authUser, error: authErr } = await supabase.auth.admin.createUser({
    email: fakeEmail,
    password: Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2),
    email_confirm: true,
  });
  if (authErr) { console.error('Auth error:', authErr.message); return; }

  const { data, error } = await supabase.from('profiles').insert({
    user_id: authUser.user.id,
    handle,
    display_name: displayName,
    type,
    location,
    bio,
    avatar_url: avatarUrl,
    social_links: instagram ? { instagram } : {},
    is_creator: false,
    is_verified: false,
    is_suspended: false,
  }).select('id').single();

  if (error) console.error('Error:', error.message);
  else console.log(`Created profile: @${handle} (${data.id})`);
}
run().catch(console.error);
