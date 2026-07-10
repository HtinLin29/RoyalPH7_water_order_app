import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (profileError || profile?.role !== 'admin') {
      return jsonResponse({ error: 'Admin access required' }, 403);
    }

    const body = await req.json();
    const { fullName, phone, email, password, avatarUrl } = body ?? {};

    if (!fullName || !phone || !email || !password) {
      return jsonResponse({ error: 'Missing required fields' }, 400);
    }

    if (String(password).length < 6) {
      return jsonResponse({ error: 'Password must be at least 6 characters' }, 400);
    }

    const { data: createdUser, error: createError } =
      await adminClient.auth.admin.createUser({
        email: String(email).trim().toLowerCase(),
        password: String(password),
        email_confirm: true,
        user_metadata: {
          full_name: String(fullName).trim(),
          phone: String(phone).trim(),
          role: 'driver',
        },
      });

    if (createError || !createdUser.user) {
      return jsonResponse(
        { error: createError?.message ?? 'Failed to create driver account' },
        400,
      );
    }

    const driverId = createdUser.user.id;

    const { error: updateError } = await adminClient
      .from('profiles')
      .update({
        full_name: String(fullName).trim(),
        phone: String(phone).trim(),
        role: 'driver',
        is_active: true,
        avatar_url: avatarUrl ?? null,
      })
      .eq('id', driverId);

    if (updateError) {
      await adminClient.auth.admin.deleteUser(driverId);
      return jsonResponse({ error: updateError.message }, 400);
    }

    return jsonResponse({ driverId }, 200);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error' },
      500,
    );
  }
});

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
