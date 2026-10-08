
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "answer_images": {
                  Row: {
                    "answer_id": string,"company_id": string,"created_at": string,"id": string,"position": number,"storage_path": string
                  }
                  Insert: {
                    "answer_id": string,"company_id": string,"created_at"?: string,"id"?: string,"position"?: number,"storage_path": string
                  }
                  Update: {
                    "answer_id"?: string,"company_id"?: string,"created_at"?: string,"id"?: string,"position"?: number,"storage_path"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "answer_images_answer_id_company_id_fkey"
      columns: ["answer_id","company_id"]
isOneToOne: false
      referencedRelation: "answers"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"answer_reviews": {
                  Row: {
                    "answer_id": string,"comment": string | null,"company_id": string,"created_at": string,"id": string,"reviewer_id": string | null,"updated_at": string,"verdict": Database["public"]['Enums']["review_verdict"]
                  }
                  Insert: {
                    "answer_id": string,"comment"?: string | null,"company_id": string,"created_at"?: string,"id"?: string,"reviewer_id"?: string | null,"updated_at"?: string,"verdict": Database["public"]['Enums']["review_verdict"]
                  }
                  Update: {
                    "answer_id"?: string,"comment"?: string | null,"company_id"?: string,"created_at"?: string,"id"?: string,"reviewer_id"?: string | null,"updated_at"?: string,"verdict"?: Database["public"]['Enums']["review_verdict"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "answer_reviews_answer_id_company_id_fkey"
      columns: ["answer_id","company_id"]
isOneToOne: false
      referencedRelation: "answers"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "answer_reviews_reviewer_id_fkey"
      columns: ["reviewer_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"answers": {
                  Row: {
                    "assignment_id": string,"attempt_no": number,"body": string,"company_id": string,"created_at": string,"exercise_id": string,"id": string,"updated_at": string
                  }
                  Insert: {
                    "assignment_id": string,"attempt_no": number,"body"?: string,"company_id": string,"created_at"?: string,"exercise_id": string,"id"?: string,"updated_at"?: string
                  }
                  Update: {
                    "assignment_id"?: string,"attempt_no"?: number,"body"?: string,"company_id"?: string,"created_at"?: string,"exercise_id"?: string,"id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "answers_assignment_id_company_id_fkey"
      columns: ["assignment_id","company_id"]
isOneToOne: false
      referencedRelation: "assignments"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "answers_exercise_id_company_id_fkey"
      columns: ["exercise_id","company_id"]
isOneToOne: false
      referencedRelation: "homework_exercises"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"assignment_submissions": {
                  Row: {
                    "assignment_id": string,"attempt_no": number,"company_id": string,"created_at": string,"id": string,"outcome": Database["public"]['Enums']["submission_outcome"] | null,"outcome_at": string | null,"reviewed_by": string | null,"submitted_at": string,"updated_at": string
                  }
                  Insert: {
                    "assignment_id": string,"attempt_no": number,"company_id": string,"created_at"?: string,"id"?: string,"outcome"?: Database["public"]['Enums']["submission_outcome"] | null,"outcome_at"?: string | null,"reviewed_by"?: string | null,"submitted_at"?: string,"updated_at"?: string
                  }
                  Update: {
                    "assignment_id"?: string,"attempt_no"?: number,"company_id"?: string,"created_at"?: string,"id"?: string,"outcome"?: Database["public"]['Enums']["submission_outcome"] | null,"outcome_at"?: string | null,"reviewed_by"?: string | null,"submitted_at"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "assignment_submissions_assignment_id_company_id_fkey"
      columns: ["assignment_id","company_id"]
isOneToOne: false
      referencedRelation: "assignments"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "assignment_submissions_reviewed_by_fkey"
      columns: ["reviewed_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"assignments": {
                  Row: {
                    "company_id": string,"created_at": string,"current_attempt": number,"due_at_override": string | null,"homework_id": string,"id": string,"reviewed_at": string | null,"started_at": string | null,"status": Database["public"]['Enums']["assignment_status"],"student_id": string,"submitted_at": string | null,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"current_attempt"?: number,"due_at_override"?: string | null,"homework_id": string,"id"?: string,"reviewed_at"?: string | null,"started_at"?: string | null,"status"?: Database["public"]['Enums']["assignment_status"],"student_id": string,"submitted_at"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"current_attempt"?: number,"due_at_override"?: string | null,"homework_id"?: string,"id"?: string,"reviewed_at"?: string | null,"started_at"?: string | null,"status"?: Database["public"]['Enums']["assignment_status"],"student_id"?: string,"submitted_at"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "assignments_company_id_student_id_fkey"
      columns: ["company_id","student_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "assignments_homework_id_company_id_fkey"
      columns: ["homework_id","company_id"]
isOneToOne: false
      referencedRelation: "homeworks"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"companies": {
                  Row: {
                    "created_at": string,"created_by": string | null,"id": string,"is_personal": boolean,"name": string,"updated_at": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by"?: string | null,"id"?: string,"is_personal"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string | null,"id"?: string,"is_personal"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "companies_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"event_participants": {
                  Row: {
                    "attendance": Database["public"]['Enums']["attendance_status"] | null,"company_id": string,"created_at": string,"event_id": string,"id": string,"role": Database["public"]['Enums']["participant_role"],"updated_at": string,"user_id": string
                  }
                  Insert: {
                    "attendance"?: Database["public"]['Enums']["attendance_status"] | null,"company_id": string,"created_at"?: string,"event_id": string,"id"?: string,"role": Database["public"]['Enums']["participant_role"],"updated_at"?: string,"user_id": string
                  }
                  Update: {
                    "attendance"?: Database["public"]['Enums']["attendance_status"] | null,"company_id"?: string,"created_at"?: string,"event_id"?: string,"id"?: string,"role"?: Database["public"]['Enums']["participant_role"],"updated_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "event_participants_company_id_user_id_fkey"
      columns: ["company_id","user_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "event_participants_event_id_company_id_fkey"
      columns: ["event_id","company_id"]
isOneToOne: false
      referencedRelation: "events"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"event_types": {
                  Row: {
                    "company_id": string,"created_at": string,"created_by": string | null,"id": string,"is_default": boolean,"name": string,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"is_default"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"is_default"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "event_types_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "event_types_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"events": {
                  Row: {
                    "cancelled_at": string | null,"company_id": string,"created_at": string,"created_by": string | null,"description": string | null,"ends_at": string,"event_type_id": string,"id": string,"is_detached": boolean,"location": string | null,"meeting_url": string | null,"original_starts_at": string | null,"series_id": string | null,"source_group_id": string | null,"starts_at": string,"status": Database["public"]['Enums']["event_status"],"title": string | null,"updated_at": string
                  }
                  Insert: {
                    "cancelled_at"?: string | null,"company_id": string,"created_at"?: string,"created_by"?: string | null,"description"?: string | null,"ends_at": string,"event_type_id": string,"id"?: string,"is_detached"?: boolean,"location"?: string | null,"meeting_url"?: string | null,"original_starts_at"?: string | null,"series_id"?: string | null,"source_group_id"?: string | null,"starts_at": string,"status"?: Database["public"]['Enums']["event_status"],"title"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "cancelled_at"?: string | null,"company_id"?: string,"created_at"?: string,"created_by"?: string | null,"description"?: string | null,"ends_at"?: string,"event_type_id"?: string,"id"?: string,"is_detached"?: boolean,"location"?: string | null,"meeting_url"?: string | null,"original_starts_at"?: string | null,"series_id"?: string | null,"source_group_id"?: string | null,"starts_at"?: string,"status"?: Database["public"]['Enums']["event_status"],"title"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "events_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "events_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "events_event_type_id_company_id_fkey"
      columns: ["event_type_id","company_id"]
isOneToOne: false
      referencedRelation: "event_types"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "events_series_id_company_id_fkey"
      columns: ["series_id","company_id"]
isOneToOne: false
      referencedRelation: "lesson_series"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "events_source_group_id_company_id_fkey"
      columns: ["source_group_id","company_id"]
isOneToOne: false
      referencedRelation: "groups"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"exercise_template_images": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"position": number,"storage_path": string,"template_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"position"?: number,"storage_path": string,"template_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"position"?: number,"storage_path"?: string,"template_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "exercise_template_images_template_id_company_id_fkey"
      columns: ["template_id","company_id"]
isOneToOne: false
      referencedRelation: "exercise_templates"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"exercise_templates": {
                  Row: {
                    "author_id": string | null,"company_id": string,"created_at": string,"description": string,"id": string,"level_id": string | null,"school_class_id": string | null,"updated_at": string,"visibility": Database["public"]['Enums']["visibility"]
                  }
                  Insert: {
                    "author_id"?: string | null,"company_id": string,"created_at"?: string,"description": string,"id"?: string,"level_id"?: string | null,"school_class_id"?: string | null,"updated_at"?: string,"visibility"?: Database["public"]['Enums']["visibility"]
                  }
                  Update: {
                    "author_id"?: string | null,"company_id"?: string,"created_at"?: string,"description"?: string,"id"?: string,"level_id"?: string | null,"school_class_id"?: string | null,"updated_at"?: string,"visibility"?: Database["public"]['Enums']["visibility"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "exercise_templates_company_id_author_id_fkey"
      columns: ["company_id","author_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "exercise_templates_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "exercise_templates_level_id_company_id_fkey"
      columns: ["level_id","company_id"]
isOneToOne: false
      referencedRelation: "levels"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "exercise_templates_school_class_id_company_id_fkey"
      columns: ["school_class_id","company_id"]
isOneToOne: false
      referencedRelation: "school_classes"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"group_members": {
                  Row: {
                    "company_id": string,"created_at": string,"group_id": string,"student_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"group_id": string,"student_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"group_id"?: string,"student_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "group_members_company_id_student_id_fkey"
      columns: ["company_id","student_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "group_members_group_id_company_id_fkey"
      columns: ["group_id","company_id"]
isOneToOne: false
      referencedRelation: "groups"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"group_teachers": {
                  Row: {
                    "company_id": string,"created_at": string,"group_id": string,"teacher_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"group_id": string,"teacher_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"group_id"?: string,"teacher_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "group_teachers_company_id_teacher_id_fkey"
      columns: ["company_id","teacher_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "group_teachers_group_id_company_id_fkey"
      columns: ["group_id","company_id"]
isOneToOne: false
      referencedRelation: "groups"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"groups": {
                  Row: {
                    "company_id": string,"created_at": string,"created_by": string | null,"id": string,"name": string,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "groups_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "groups_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"homework_exercise_images": {
                  Row: {
                    "company_id": string,"created_at": string,"exercise_id": string,"id": string,"position": number,"storage_path": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"exercise_id": string,"id"?: string,"position"?: number,"storage_path": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"exercise_id"?: string,"id"?: string,"position"?: number,"storage_path"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "homework_exercise_images_exercise_id_company_id_fkey"
      columns: ["exercise_id","company_id"]
isOneToOne: false
      referencedRelation: "homework_exercises"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"homework_exercises": {
                  Row: {
                    "company_id": string,"created_at": string,"description": string,"homework_id": string,"id": string,"position": number,"source_template_id": string | null,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"description": string,"homework_id": string,"id"?: string,"position"?: number,"source_template_id"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"description"?: string,"homework_id"?: string,"id"?: string,"position"?: number,"source_template_id"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "homework_exercises_homework_id_company_id_fkey"
      columns: ["homework_id","company_id"]
isOneToOne: false
      referencedRelation: "homeworks"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "homework_exercises_source_template_id_fkey"
      columns: ["source_template_id"]
isOneToOne: false
      referencedRelation: "exercise_templates"
      referencedColumns: ["id"]
    }
                  ]
                },"homeworks": {
                  Row: {
                    "author_id": string | null,"company_id": string,"created_at": string,"created_by": string | null,"description": string | null,"due_at": string,"event_id": string | null,"id": string,"source_group_id": string | null,"title": string,"updated_at": string
                  }
                  Insert: {
                    "author_id"?: string | null,"company_id": string,"created_at"?: string,"created_by"?: string | null,"description"?: string | null,"due_at": string,"event_id"?: string | null,"id"?: string,"source_group_id"?: string | null,"title": string,"updated_at"?: string
                  }
                  Update: {
                    "author_id"?: string | null,"company_id"?: string,"created_at"?: string,"created_by"?: string | null,"description"?: string | null,"due_at"?: string,"event_id"?: string | null,"id"?: string,"source_group_id"?: string | null,"title"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "homeworks_company_id_author_id_fkey"
      columns: ["company_id","author_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "homeworks_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "homeworks_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "homeworks_event_id_company_id_fkey"
      columns: ["event_id","company_id"]
isOneToOne: false
      referencedRelation: "events"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "homeworks_source_group_id_company_id_fkey"
      columns: ["source_group_id","company_id"]
isOneToOne: false
      referencedRelation: "groups"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"invite_failed_attempts": {
                  Row: {
                    "attempted_at": string,"id": number,"user_id": string
                  }
                  Insert: {
                    "attempted_at"?: string,"id"?: never,"user_id": string
                  }
                  Update: {
                    "attempted_at"?: string,"id"?: never,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "invite_failed_attempts_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"invite_redemptions": {
                  Row: {
                    "id": string,"invite_id": string,"redeemed_at": string,"user_id": string
                  }
                  Insert: {
                    "id"?: string,"invite_id": string,"redeemed_at"?: string,"user_id": string
                  }
                  Update: {
                    "id"?: string,"invite_id"?: string,"redeemed_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "invite_redemptions_invite_id_fkey"
      columns: ["invite_id"]
isOneToOne: false
      referencedRelation: "invites"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "invite_redemptions_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"invites": {
                  Row: {
                    "code": string,"company_id": string,"created_at": string,"created_by": string,"expires_at": string,"id": string,"max_uses": number,"payload": NonNullable<Json>,"revoked_at": string | null,"role": Database["public"]['Enums']["member_role"],"updated_at": string,"use_count": number
                  }
                  Insert: {
                    "code"?: string,"company_id": string,"created_at"?: string,"created_by": string,"expires_at": string,"id"?: string,"max_uses"?: number,"payload"?: NonNullable<Json>,"revoked_at"?: string | null,"role"?: Database["public"]['Enums']["member_role"],"updated_at"?: string,"use_count"?: number
                  }
                  Update: {
                    "code"?: string,"company_id"?: string,"created_at"?: string,"created_by"?: string,"expires_at"?: string,"id"?: string,"max_uses"?: number,"payload"?: NonNullable<Json>,"revoked_at"?: string | null,"role"?: Database["public"]['Enums']["member_role"],"updated_at"?: string,"use_count"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "invites_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "invites_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"lesson_series": {
                  Row: {
                    "company_id": string,"created_at": string,"created_by": string | null,"description": string | null,"duration": string,"event_type_id": string,"first_starts_at": string,"id": string,"last_starts_at": string,"location": string | null,"meeting_url": string | null,"rrule": string,"source_group_id": string | null,"split_from_series_id": string | null,"timezone": string,"title": string | null,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"created_by"?: string | null,"description"?: string | null,"duration": string,"event_type_id": string,"first_starts_at": string,"id"?: string,"last_starts_at": string,"location"?: string | null,"meeting_url"?: string | null,"rrule": string,"source_group_id"?: string | null,"split_from_series_id"?: string | null,"timezone": string,"title"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"created_by"?: string | null,"description"?: string | null,"duration"?: string,"event_type_id"?: string,"first_starts_at"?: string,"id"?: string,"last_starts_at"?: string,"location"?: string | null,"meeting_url"?: string | null,"rrule"?: string,"source_group_id"?: string | null,"split_from_series_id"?: string | null,"timezone"?: string,"title"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "lesson_series_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "lesson_series_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "lesson_series_event_type_id_company_id_fkey"
      columns: ["event_type_id","company_id"]
isOneToOne: false
      referencedRelation: "event_types"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "lesson_series_source_group_id_company_id_fkey"
      columns: ["source_group_id","company_id"]
isOneToOne: false
      referencedRelation: "groups"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "lesson_series_split_from_series_id_fkey"
      columns: ["split_from_series_id"]
isOneToOne: false
      referencedRelation: "lesson_series"
      referencedColumns: ["id"]
    }
                  ]
                },"lesson_series_participants": {
                  Row: {
                    "company_id": string,"created_at": string,"role": Database["public"]['Enums']["participant_role"],"series_id": string,"user_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"role": Database["public"]['Enums']["participant_role"],"series_id": string,"user_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"role"?: Database["public"]['Enums']["participant_role"],"series_id"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "lesson_series_participants_company_id_user_id_fkey"
      columns: ["company_id","user_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "lesson_series_participants_series_id_company_id_fkey"
      columns: ["series_id","company_id"]
isOneToOne: false
      referencedRelation: "lesson_series"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"levels": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"name": string,"position": number,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"name": string,"position"?: number,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"name"?: string,"position"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "levels_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    }
                  ]
                },"memberships": {
                  Row: {
                    "can_teach": boolean,"company_id": string,"created_at": string,"id": string,"role": Database["public"]['Enums']["member_role"],"updated_at": string,"user_id": string
                  }
                  Insert: {
                    "can_teach"?: boolean,"company_id": string,"created_at"?: string,"id"?: string,"role": Database["public"]['Enums']["member_role"],"updated_at"?: string,"user_id": string
                  }
                  Update: {
                    "can_teach"?: boolean,"company_id"?: string,"created_at"?: string,"id"?: string,"role"?: Database["public"]['Enums']["member_role"],"updated_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "memberships_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "memberships_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"note_copies": {
                  Row: {
                    "author_id": string | null,"body": string,"company_id": string,"created_at": string,"event_id": string | null,"homework_id": string | null,"id": string,"source_group_id": string | null,"source_note_id": string | null,"title": string,"updated_at": string
                  }
                  Insert: {
                    "author_id"?: string | null,"body"?: string,"company_id": string,"created_at"?: string,"event_id"?: string | null,"homework_id"?: string | null,"id"?: string,"source_group_id"?: string | null,"source_note_id"?: string | null,"title": string,"updated_at"?: string
                  }
                  Update: {
                    "author_id"?: string | null,"body"?: string,"company_id"?: string,"created_at"?: string,"event_id"?: string | null,"homework_id"?: string | null,"id"?: string,"source_group_id"?: string | null,"source_note_id"?: string | null,"title"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "note_copies_company_id_author_id_fkey"
      columns: ["company_id","author_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "note_copies_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "note_copies_event_id_company_id_fkey"
      columns: ["event_id","company_id"]
isOneToOne: false
      referencedRelation: "events"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "note_copies_homework_id_company_id_fkey"
      columns: ["homework_id","company_id"]
isOneToOne: false
      referencedRelation: "homeworks"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "note_copies_source_group_id_company_id_fkey"
      columns: ["source_group_id","company_id"]
isOneToOne: false
      referencedRelation: "groups"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "note_copies_source_note_id_fkey"
      columns: ["source_note_id"]
isOneToOne: false
      referencedRelation: "notes"
      referencedColumns: ["id"]
    }
                  ]
                },"note_copy_images": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"note_copy_id": string,"position": number,"storage_path": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"note_copy_id": string,"position"?: number,"storage_path": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"note_copy_id"?: string,"position"?: number,"storage_path"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "note_copy_images_note_copy_id_company_id_fkey"
      columns: ["note_copy_id","company_id"]
isOneToOne: false
      referencedRelation: "note_copies"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"note_copy_recipients": {
                  Row: {
                    "company_id": string,"created_at": string,"note_copy_id": string,"student_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"note_copy_id": string,"student_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"note_copy_id"?: string,"student_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "note_copy_recipients_company_id_student_id_fkey"
      columns: ["company_id","student_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "note_copy_recipients_note_copy_id_company_id_fkey"
      columns: ["note_copy_id","company_id"]
isOneToOne: false
      referencedRelation: "note_copies"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"note_images": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"note_id": string,"position": number,"storage_path": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"note_id": string,"position"?: number,"storage_path": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"note_id"?: string,"position"?: number,"storage_path"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "note_images_note_id_company_id_fkey"
      columns: ["note_id","company_id"]
isOneToOne: false
      referencedRelation: "notes"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"note_tags": {
                  Row: {
                    "company_id": string,"created_at": string,"note_id": string,"tag_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"note_id": string,"tag_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"note_id"?: string,"tag_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "note_tags_note_id_company_id_fkey"
      columns: ["note_id","company_id"]
isOneToOne: false
      referencedRelation: "notes"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "note_tags_tag_id_company_id_fkey"
      columns: ["tag_id","company_id"]
isOneToOne: false
      referencedRelation: "tags"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"notes": {
                  Row: {
                    "author_id": string | null,"body": string,"company_id": string,"created_at": string,"id": string,"level_id": string | null,"school_class_id": string | null,"title": string,"updated_at": string,"visibility": Database["public"]['Enums']["visibility"]
                  }
                  Insert: {
                    "author_id"?: string | null,"body"?: string,"company_id": string,"created_at"?: string,"id"?: string,"level_id"?: string | null,"school_class_id"?: string | null,"title": string,"updated_at"?: string,"visibility"?: Database["public"]['Enums']["visibility"]
                  }
                  Update: {
                    "author_id"?: string | null,"body"?: string,"company_id"?: string,"created_at"?: string,"id"?: string,"level_id"?: string | null,"school_class_id"?: string | null,"title"?: string,"updated_at"?: string,"visibility"?: Database["public"]['Enums']["visibility"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "notes_company_id_author_id_fkey"
      columns: ["company_id","author_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "notes_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "notes_level_id_company_id_fkey"
      columns: ["level_id","company_id"]
isOneToOne: false
      referencedRelation: "levels"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "notes_school_class_id_company_id_fkey"
      columns: ["school_class_id","company_id"]
isOneToOne: false
      referencedRelation: "school_classes"
      referencedColumns: ["id","company_id"]
    }
                  ]
                },"profiles": {
                  Row: {
                    "avatar_path": string | null,"created_at": string,"full_name": string,"id": string,"timezone": string,"updated_at": string
                  }
                  Insert: {
                    "avatar_path"?: string | null,"created_at"?: string,"full_name"?: string,"id": string,"timezone"?: string,"updated_at"?: string
                  }
                  Update: {
                    "avatar_path"?: string | null,"created_at"?: string,"full_name"?: string,"id"?: string,"timezone"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"push_tokens": {
                  Row: {
                    "created_at": string,"id": string,"platform": Database["public"]['Enums']["push_platform"],"token": string,"updated_at": string,"user_id": string
                  }
                  Insert: {
                    "created_at"?: string,"id"?: string,"platform": Database["public"]['Enums']["push_platform"],"token": string,"updated_at"?: string,"user_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"platform"?: Database["public"]['Enums']["push_platform"],"token"?: string,"updated_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "push_tokens_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"school_classes": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"name": string,"position": number,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"name": string,"position"?: number,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"name"?: string,"position"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "school_classes_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    }
                  ]
                },"tags": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"name": string,"owner_id": string | null,"updated_at": string,"visibility": Database["public"]['Enums']["visibility"]
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"name": string,"owner_id"?: string | null,"updated_at"?: string,"visibility"?: Database["public"]['Enums']["visibility"]
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"name"?: string,"owner_id"?: string | null,"updated_at"?: string,"visibility"?: Database["public"]['Enums']["visibility"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "tags_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "tags_company_id_owner_id_fkey"
      columns: ["company_id","owner_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    }
                  ]
                },"teacher_students": {
                  Row: {
                    "company_id": string,"created_at": string,"id": string,"is_direct": boolean,"student_id": string,"teacher_id": string,"updated_at": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"id"?: string,"is_direct"?: boolean,"student_id": string,"teacher_id": string,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"id"?: string,"is_direct"?: boolean,"student_id"?: string,"teacher_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "teacher_students_company_id_student_id_fkey"
      columns: ["company_id","student_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    },{
      foreignKeyName: "teacher_students_company_id_teacher_id_fkey"
      columns: ["company_id","teacher_id"]
isOneToOne: false
      referencedRelation: "memberships"
      referencedColumns: ["company_id","user_id"]
    }
                  ]
                },"template_tags": {
                  Row: {
                    "company_id": string,"created_at": string,"tag_id": string,"template_id": string
                  }
                  Insert: {
                    "company_id": string,"created_at"?: string,"tag_id": string,"template_id": string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"tag_id"?: string,"template_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "template_tags_tag_id_company_id_fkey"
      columns: ["tag_id","company_id"]
isOneToOne: false
      referencedRelation: "tags"
      referencedColumns: ["id","company_id"]
    },{
      foreignKeyName: "template_tags_template_id_company_id_fkey"
      columns: ["template_id","company_id"]
isOneToOne: false
      referencedRelation: "exercise_templates"
      referencedColumns: ["id","company_id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "create_lesson_series":
{ Args: { "p_company_id": string,"p_description"?: string,"p_duration": string,"p_event_type_id": string,"p_location"?: string,"p_meeting_url"?: string,"p_occurrences": (string)[],"p_participants": Json,"p_rrule": string,"p_source_group_id"?: string,"p_timezone": string,"p_title"?: string }; Returns: string
                           },
"create_personal_workspace":
{ Args: { "p_name"?: string }; Returns: string
                           },
"preview_invite":
{ Args: { "p_code": string }; Returns: {
              "company_name": string,"inviter_name": string,"role": Database["public"]['Enums']["member_role"]
            }[]
                           },
"redeem_invite":
{ Args: { "p_code": string }; Returns: {
              "company_id": string,"result": Database["public"]['Enums']["redeem_invite_result"]
            }[]
                           },
"review_assignment":
{ Args: { "p_assignment_id": string,"p_outcome": Database["public"]['Enums']["submission_outcome"] }; Returns: {
              "company_id": string,
"created_at": string,
"current_attempt": number,
"due_at_override": string | null,
"homework_id": string,
"id": string,
"reviewed_at": string | null,
"started_at": string | null,
"status": Database["public"]['Enums']["assignment_status"],
"student_id": string,
"submitted_at": string | null,
"updated_at": string
            }
                          SetofOptions: {
        from: "*"
        to: "assignments"
        isOneToOne: true
        isSetofReturn: false
      } },
"split_lesson_series":
{ Args: { "p_description"?: string,"p_duration": string,"p_event_type_id"?: string,"p_from": string,"p_location"?: string,"p_meeting_url"?: string,"p_occurrences": (string)[],"p_old_rrule": string,"p_participants": Json,"p_rrule": string,"p_series_id": string,"p_timezone": string,"p_title"?: string }; Returns: string
                           },
"submit_assignment":
{ Args: { "p_assignment_id": string }; Returns: {
              "company_id": string,
"created_at": string,
"current_attempt": number,
"due_at_override": string | null,
"homework_id": string,
"id": string,
"reviewed_at": string | null,
"started_at": string | null,
"status": Database["public"]['Enums']["assignment_status"],
"student_id": string,
"submitted_at": string | null,
"updated_at": string
            }
                          SetofOptions: {
        from: "*"
        to: "assignments"
        isOneToOne: true
        isSetofReturn: false
      } },
"unlink_teacher_student":
{ Args: { "p_company": string,"p_student": string,"p_teacher": string }; Returns: undefined
                           }
          }
          Enums: {
            "assignment_status": "assigned"|"in_progress"|"submitted"|"reviewed"|"returned","attendance_status": "present"|"absent"|"excused","event_status": "scheduled"|"cancelled","member_role": "owner"|"admin"|"teacher"|"student","participant_role": "teacher"|"student","push_platform": "ios"|"android","redeem_invite_result": "ok"|"invalid"|"expired"|"revoked"|"exhausted"|"role_conflict"|"rate_limited","review_verdict": "correct"|"partial"|"incorrect","submission_outcome": "reviewed"|"returned","visibility": "private"|"company"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {
            
          }
        },"public": {
          Enums: {
            "assignment_status": ["assigned", "in_progress", "submitted", "reviewed", "returned"],"attendance_status": ["present", "absent", "excused"],"event_status": ["scheduled", "cancelled"],"member_role": ["owner", "admin", "teacher", "student"],"participant_role": ["teacher", "student"],"push_platform": ["ios", "android"],"redeem_invite_result": ["ok", "invalid", "expired", "revoked", "exhausted", "role_conflict", "rate_limited"],"review_verdict": ["correct", "partial", "incorrect"],"submission_outcome": ["reviewed", "returned"],"visibility": ["private", "company"]
          }
        }
} as const
