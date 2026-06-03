const { createClient } = require('@supabase/supabase-js');
require('fs').readFileSync('.env.local', 'utf8').split('\n').forEach(l => {
  const [k, v] = l.split('=');
  if (k && v) process.env[k.trim()] = v.trim();
});

const s = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const u = id => `https://images.unsplash.com/photo-${id}?w=960&h=1200&fit=crop&q=85`;

const updates = [
  // Clothing
  { title: 'Cosmic Cargo Pants',            images: [u('LKU2gMp_q98'), u('mU8UI1-DHGM')] },
  { title: 'Mandala Print Tee',             images: [u('r4SC6gX2dEs'), u('3yqt17yQ2as')] },
  { title: 'Fractal Geometry Hoodie',       images: [u('jV3PeSkXFF8'), u('mnCLpbBngWY')] },
  { title: 'UV Reactive Hoodie',            images: [u('tFWdz-uK6eA'), u('kw5MPkFP5K8')] },
  { title: 'Tribal Wrap Dress',             images: [u('EWRMCdNUVvI'), u('t9mWFZcFwLk')] },
  { title: 'Psydelic Flow Jacket',          images: [u('RPnRSbQuJ-g'), u('FrYnCwjXhXs')] },
  { title: 'Sacred Patchwork Jacket',       images: [u('hdjjZXmeQRU'), u('w71RJeYbhYk')] },
  { title: 'Shaman Cloak',                  images: [u('eNm_gu3JX2M'), u('UKTsHysE-nU')] },
  { title: 'Flow Arts Leggings',            images: [u('XYJBcDKpUqU'), u('NfsOweDxKmE')] },
  { title: 'Festival Kimono',               images: [u('U433-R-g7QY'), u('EXxzcDnvP8w')] },
  // Accessories
  { title: 'Amethyst Pendant',              images: [u('hfV9tSBEvlU'), u('V0ovfEDz-A0'), u('DBqjm7HXTdU')] },
  // Gear
  { title: 'Handpan Drum — D Minor',        images: [u('KnUL3RvOe5A'), u('sety58tR6fI')] },
  { title: 'Moog Grandmother Semi-Modular', images: [u('TZWrGT6RsVg'), u('aVOACNd1cc0')] },
  { title: 'Elektron Digitakt',             images: [u('WFIoD6zWn98'), u('9ZRqoZoyCPs')] },
  { title: 'Roland DJ-707M Controller',     images: [u('u0BVH8IOTUk'), u('CpCgOckQhRg')] },
  { title: 'Korg Minilogue XD',             images: [u('11KDGL-cN5s'), u('WXtKI7N9j_Q')] },
  { title: 'Focusrite Scarlett 2i2 Studio', images: [u('6_5GsNI61UU'), u('RGGJerL_ag0')] },
  { title: 'Boss RE-202 Space Echo',        images: [u('w2UMoPrbutU'), u('zPo9pPnUNdA')] },
  { title: 'Native Instruments Maschine+',  images: [u('JyCvrH68uVk'), u('Bmk7ttLve3Y')] },
  { title: 'Strymon BigSky Reverb Pedal',   images: [u('zKFxgSuc4vc'), u('9ZRqoZoyCPs')] },
];

Promise.all(updates.map(row => s.from('listings').update({ images: row.images }).eq('title', row.title)))
  .then(results => {
    const errors = results.filter(r => r.error);
    console.log(errors.length
      ? 'Errors: ' + errors.map(r => r.error?.message).join(', ')
      : `Updated ${updates.length} listings with Unsplash images`);
  });
