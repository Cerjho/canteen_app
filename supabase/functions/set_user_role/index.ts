/**
 * Supabase Edge Function: set_user_role
 * 
 * Purpose:
 * - Set user roles using Supabase user_metadata
 * - Replaces Firebase custom claims functionality
 * - Supports admin, parent, and other roles
 * 
 * Migrated from: tools/set_custom_claims.js
 * 
 * In Supabase, instead of Firebase custom claims, we use:
 * - user_metadata: for roles and other user attributes
 * - app_metadata: for system-controlled data (requires service role)
 * 
 * Usage from Flutter:
 * ```dart
 * final response = await supabase.functions.invoke('set_user_role', body: {
 *   'user_id': 'user-uuid',
 *   'isAdmin': true,
 *   'isParent': false,
 * });
 * ```
 * 
 * Environment Variables:
 * - SUPABASE_URL: Auto-configured
 * - SUPABASE_SERVICE_ROLE_KEY: Auto-configured (required for admin operations)
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface SetRoleRequest {
  user_id: string;
  isAdmin?: boolean | null;
  isParent?: boolean | null;
  role?: string; // Legacy support: "admin" or "parent"
}

interface UserMetadata {
  isAdmin?: boolean;
  isParent?: boolean;
  updatedAt?: string;
  [key: string]: unknown;
}

serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Parse request body
    let body: SetRoleRequest;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Validate user_id
    if (!body.user_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: user_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client with service role for admin access
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    );

    // Get current user metadata to merge with new values
    const { data: currentUser, error: fetchError } = await supabase.auth.admin.getUserById(
      body.user_id
    );

    if (fetchError || !currentUser) {
      console.error("Failed to fetch user:", fetchError);
      return new Response(
        JSON.stringify({ 
          error: "User not found",
          details: fetchError?.message 
        }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build updated metadata by merging existing with new values
    const existingMetadata = (currentUser.user.user_metadata || {}) as UserMetadata;
    const updatedMetadata: UserMetadata = { ...existingMetadata };

    // Handle legacy "role" field
    if (body.role) {
      const roleLower = body.role.toLowerCase();
      if (roleLower === "admin") {
        updatedMetadata.isAdmin = true;
        updatedMetadata.isParent = false;
      } else if (roleLower === "parent") {
        updatedMetadata.isAdmin = false;
        updatedMetadata.isParent = true;
      }
    }

    // Handle explicit boolean flags (these take precedence over legacy role)
    if (body.isAdmin !== undefined && body.isAdmin !== null) {
      updatedMetadata.isAdmin = Boolean(body.isAdmin);
    }
    if (body.isParent !== undefined && body.isParent !== null) {
      updatedMetadata.isParent = Boolean(body.isParent);
    }

    // Ensure at least one role flag is set (default to parent if none specified)
    if (updatedMetadata.isAdmin === undefined && updatedMetadata.isParent === undefined) {
      updatedMetadata.isAdmin = false;
      updatedMetadata.isParent = true;
    }

    // Add timestamp
    updatedMetadata.updatedAt = new Date().toISOString();

    // Update user metadata
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      body.user_id,
      {
        user_metadata: updatedMetadata
      }
    );

    if (updateError) {
      console.error("Failed to update user:", updateError);
      return new Response(
        JSON.stringify({ 
          error: "Failed to update user role",
          details: updateError.message 
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Log success
    console.log(`Successfully updated roles for user ${body.user_id}:`, {
      isAdmin: updatedMetadata.isAdmin,
      isParent: updatedMetadata.isParent
    });

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        message: "User role updated successfully",
        user_id: body.user_id,
        roles: {
          isAdmin: updatedMetadata.isAdmin,
          isParent: updatedMetadata.isParent
        },
        note: "User must refresh their session to see updated metadata"
      }),
      { 
        status: 200, 
        headers: { "Content-Type": "application/json" } 
      }
    );

  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        message: error instanceof Error ? error.message : String(error)
      }),
      { 
        status: 500, 
        headers: { "Content-Type": "application/json" } 
      }
    );
  }
});

/**
 * Example usage from Flutter:
 * 
 * // Set user as admin
 * await supabase.functions.invoke('set_user_role', body: {
 *   'user_id': userId,
 *   'isAdmin': true,
 *   'isParent': false,
 * });
 * 
 * // Set user as parent
 * await supabase.functions.invoke('set_user_role', body: {
 *   'user_id': userId,
 *   'isAdmin': false,
 *   'isParent': true,
 * });
 * 
 * // Access role in Flutter after refresh:
 * final user = supabase.auth.currentUser;
 * final isAdmin = user?.userMetadata?['isAdmin'] ?? false;
 * final isParent = user?.userMetadata?['isParent'] ?? false;
 * 
 * // Refresh user session to get updated metadata:
 * await supabase.auth.refreshSession();
 */
