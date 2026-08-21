#!/usr/bin/env python3
"""Generate a clean Entity-Relationship (ER) database architecture diagram
for the BrisConnect SQL schema using Graphviz (DOT).
"""

from pathlib import Path

from graphviz import Digraph


def main():
    out_dir = Path(__file__).parent
    dot = Digraph(
        name="BrisConnect_Database_Architecture",
        format="pdf",
        engine="dot",
    )
    dot.attr(
        rankdir="LR",
        bgcolor="#FFFFFF",
        fontname="Helvetica Neue",
        fontsize="20",
        label="BrisConnect+ Database Architecture",
        labelloc="t",
        labeljust="c",
        splines="ortho",
        nodesep="0.6",
        ranksep="1.2",
        pad="0.5",
    )

    # Common node attributes
    dot.attr(
        "node",
        shape="none",
        fontname="Helvetica Neue",
        fontsize="10",
        margin="0.2,0.1",
    )
    dot.attr("edge", fontname="Helvetica Neue", fontsize="9", color="#6B7280")

    # Color palette
    colors = {
        "users": "#DBEAFE",        # blue-100
        "business": "#FEF3C7",     # amber-100
        "content": "#D1FAE5",      # green-100
        "engagement": "#EDE9FE",   # violet-100
        "messaging": "#FCE7F3",    # pink-100
        "payments": "#E0E7FF",     # indigo-100
        "system": "#F3F4F6",       # gray-100
        "border": "#374151",       # gray-700
        "header_text": "#111827",  # gray-900
    }

    def table(name, title, columns, group):
        color = colors.get(group, colors["system"])
        rows = [f'<TR><TD BGCOLOR="{color}" ALIGN="CENTER"><B><FONT COLOR="{colors["header_text"]}">{title}</FONT></B></TD></TR>']
        for col in columns:
            rows.append(f'<TR><TD ALIGN="LEFT" PORT="{col.replace(" ", "_")}">{col}</TD></TR>')
        label = f'<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="4" BGCOLOR="white" COLOR="{colors["border"]}">{"".join(rows)}</TABLE>'
        dot.node(name, label=f"<{label}>")

    # 1. AUTH / USERS
    table("admins", "admins", ["PK email", "username", "name", "role", "active", "last_login_at"], "users")
    table("local_users", "local_users", ["PK email", "username", "name", "phone", "suburb", "approval_status", "password_hash", "created_at"], "users")
    table("visitor_users", "visitor_users", ["PK email", "username", "name", "phone", "password_hash", "created_at"], "users")

    # 2. BUSINESSES
    table("businesses", "businesses", ["PK id", "FK owner_id", "business_name", "category", "description", "address", "lat/lng", "is_verified", "is_active", "deleted_at"], "business")
    table("business_menu_items", "business_menu_items", ["PK id", "FK business_id", "name", "price", "tags"], "business")
    table("food_businesses", "food_businesses", ["PK id", "name", "description", "cuisine_types", "average_rating"], "business")

    # 3. ATTRACTIONS & DISCOVER
    table("attractions", "attractions", ["PK id", "name", "description", "category", "approval_status", "latitude", "longitude"], "content")
    table("attraction_details", "attraction_details", ["PK FK attraction_id", "history", "opening_hours", "ticket_price", "rating"], "content")
    table("discover_items", "discover_items", ["PK id", "title", "section", "category", "source_provider", "date_time"], "content")

    # 4. EVENTS
    table("events", "events", ["PK id", "title", "category", "location", "FK created_by_local_email", "approval_status", "status"], "content")
    table("event_interests", "event_interests", ["PK FK event_id", "PK user_email", "PK user_type"], "content")

    # 5. BUSINESS EVENTS & PROMOTIONS
    table("business_events", "business_events", ["PK id", "FK business_id", "FK owner_id", "title", "event_date", "status"], "business")
    table("promotions", "promotions", ["PK id", "FK business_id", "FK owner_id", "title", "scheduled_at", "status"], "business")
    table("ai_generated_posts", "ai_generated_posts", ["PK id", "FK business_id", "FK owner_id", "post_type", "title", "status"], "business")

    # 6. REVIEWS
    table("reviews", "reviews", ["PK id", "FK business_id", "visitor_id", "rating", "comment", "visible", "deleted_at"], "engagement")
    table("review_reports", "review_reports", ["PK id", "FK review_id", "reporter_email", "status"], "engagement")

    # 7. SOCIAL & ENGAGEMENT
    table("social_shares", "social_shares", ["PK id", "FK business_id", "visitor_id", "platform", "share_kind", "title"], "engagement")
    table("post_engagements", "post_engagements", ["PK id", "post_type", "post_id", "action", "visitor_id"], "engagement")
    table("post_comments", "post_comments", ["PK id", "post_type", "post_id", "visitor_id", "text"], "engagement")
    table("audience_interactions", "audience_interactions", ["PK id", "FK business_id", "owner_id", "visitor_hash", "type"], "engagement")
    table("visitor_photos", "visitor_photos", ["PK id", "FK business_id", "FK event_id", "visitor_id", "image_url", "status"], "engagement")

    # 8. REPORTS & FEEDBACK
    table("event_reports", "event_reports", ["PK id", "FK event_id", "visitor_email", "reason", "status"], "messaging")
    table("app_feedback", "app_feedback", ["PK id", "reference_id", "reporter_email", "subject", "status"], "messaging")
    table("moderation_audit_log", "moderation_audit_log", ["PK id", "FK admin_email", "content_type", "decision"], "messaging")
    table("crowd_reports", "crowd_reports", ["PK id", "FK event_id", "level", "weight"], "messaging")

    # 9. NOTIFICATIONS & MESSAGING
    table("user_notifications", "user_notifications", ["PK id", "user_email", "FK event_id", "schedule_type", "is_read"], "messaging")
    table("mail_queue", "mail_queue", ["PK id", "recipient", "status", "sent_at"], "messaging")
    table("sms_queue", "sms_queue", ["PK id", "recipient", "status", "sent_at"], "messaging")
    table("notification_health_checks", "notification_health_checks", ["PK id", "check_type", "status"], "messaging")

    # 10. PAYMENTS
    table("subscription_plans", "subscription_plans", ["PK id", "name", "price_cents", "duration_days", "is_active"], "payments")
    table("business_subscriptions", "business_subscriptions", ["PK id", "FK owner_id", "FK plan_id", "status"], "payments")
    table("promotion_plans", "promotion_plans", ["PK id", "name", "price_cents", "duration_days"], "payments")
    table("business_payments", "business_payments", ["PK id", "FK owner_id", "FK plan_id", "amount_cents", "status"], "payments")

    # 11. CURATED CONTENT
    table("brisbane_stories", "brisbane_stories", ["PK id", "title", "category", "published_at"], "content")
    table("brisbane_voices", "brisbane_voices", ["PK id", "name", "quote", "approval_status"], "content")

    # 12. SYSTEM
    table("config", "config", ["PK id", "payload"], "system")
    table("event_categories", "event_categories", ["PK id", "name", "is_active"], "system")
    table("counters", "counters", ["PK id", "count"], "system")
    table("seed_metadata", "seed_metadata", ["PK id", "version", "seeded_at"], "system")

    # Subcollections of local_users
    table("local_user_fcm_tokens", "local_user_fcm_tokens", ["PK id", "FK local_user_email", "token"], "users")
    table("local_user_notifications", "local_user_notifications", ["PK id", "FK local_user_email", "title", "read"], "users")

    # Edges
    edges = [
        ("businesses", "local_users", "owner_id"),
        ("business_menu_items", "businesses", "business_id"),
        ("business_events", "businesses", "business_id"),
        ("business_events", "local_users", "owner_id"),
        ("promotions", "businesses", "business_id"),
        ("promotions", "local_users", "owner_id"),
        ("ai_generated_posts", "businesses", "business_id"),
        ("ai_generated_posts", "local_users", "owner_id"),
        ("reviews", "businesses", "business_id"),
        ("review_reports", "reviews", "review_id"),
        ("social_shares", "businesses", "business_id"),
        ("audience_interactions", "businesses", "business_id"),
        ("visitor_photos", "businesses", "business_id"),
        ("visitor_photos", "events", "event_id"),
        ("event_reports", "events", "event_id"),
        ("event_interests", "events", "event_id"),
        ("crowd_reports", "events", "event_id"),
        ("user_notifications", "events", "event_id"),
        ("attraction_details", "attractions", "attraction_id"),
        ("events", "local_users", "created_by_local_email"),
        ("business_subscriptions", "local_users", "owner_id"),
        ("business_subscriptions", "subscription_plans", "plan_id"),
        ("business_payments", "local_users", "owner_id"),
        ("business_payments", "subscription_plans", "plan_id"),
        ("business_payments", "promotion_plans", "promotion_plan_id"),
        ("local_user_fcm_tokens", "local_users", "local_user_email"),
        ("local_user_notifications", "local_users", "local_user_email"),
        ("moderation_audit_log", "admins", "admin_email"),
    ]

    for src, dst, label in edges:
        dot.edge(f"{src}:{label.replace(' ', '_')}", f"{dst}:{label.replace(' ', '_')}", label="", arrowhead="crow")

    output_path = out_dir / "brisconnect_database_architecture"
    dot.render(filename=str(output_path), cleanup=True)
    print(f"Diagram generated: {output_path}.pdf")


if __name__ == "__main__":
    main()
