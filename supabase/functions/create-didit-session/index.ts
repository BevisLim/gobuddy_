import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const diditApiKey = Deno.env.get("DIDIT_API_KEY");
    const diditWorkflowId = Deno.env.get("DIDIT_WORKFLOW_ID");

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey ||
        !diditApiKey || !diditWorkflowId) {
      return jsonResponse({ error: "Server configuration is incomplete" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userError } =
      await userClient.auth.getUser(token);
    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const diditResponse = await fetch(
      "https://verification.didit.me/v3/session/",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": diditApiKey,
        },
        body: JSON.stringify({
          workflow_id: diditWorkflowId,
          vendor_data: user.id,
        }),
      },
    );
    const diditData = await diditResponse.json();

    if (!diditResponse.ok) {
      console.error("Didit session creation failed:", diditResponse.status);
      return jsonResponse(
        { error: "Failed to create Didit verification session" },
        diditResponse.status,
      );
    }

    const sessionId = diditData.session_id;
    const verificationUrl = diditData.url ?? diditData.session_url;
    if (!sessionId || !verificationUrl) {
      return jsonResponse(
        { error: "Didit returned an invalid session response" },
        500,
      );
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error: insertError } = await adminClient
      .from("identity_verifications")
      .insert({
        user_id: user.id,
        provider: "didit",
        provider_session_id: sessionId,
        status: "not_started",
        submitted_at: new Date().toISOString(),
      });
    if (insertError) {
      console.error("Failed to save identity verification:", insertError);
      return jsonResponse(
        { error: "Verification session created but database save failed" },
        500,
      );
    }

    const { error: profileError } = await adminClient
      .from("user_accounts")
      .update({ verification_status: "pending" })
      .eq("id", user.id);
    if (profileError) {
      console.error("Failed to update user account:", profileError);
      return jsonResponse(
        { error: "Verification session saved but profile update failed" },
        500,
      );
    }

    return jsonResponse({
      session_id: sessionId,
      verification_url: verificationUrl,
      status: diditData.status,
    });
  } catch (error) {
    console.error("Unexpected verification error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
