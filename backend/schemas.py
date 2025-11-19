from marshmallow import Schema, fields, validate

# --- Internal RAG and Context Schema ---
# This schema models the input data structure assembled by the backend
# from the user's location, the hazard, and the playbook/signals.
# It is used for preparing the LLM prompt.
class HazardContextSchema(Schema):
    """
    The RAG Context assembled before generating the final prompt for the LLM.
    """
    # The user's latitude
    lat = fields.Float(required=True, validate=validate.Range(min=-90, max=90))
    # The user's longitude
    lng = fields.Float(required=True, validate=validate.Range(min=-180, max=180))
    # The normalized hazard type (e.g., "Road Closure")
    hazard_type = fields.Str(required=True)
    # Raw JSON/object from APIs like Mapbox (e.g., traffic incident reports)
    raw_signals = fields.Dict() 
    # Chunks of relevant text from your Playbooks (e.g., mock_playbook_*.txt)
    playbook_chunks = fields.List(fields.Str())

# --- Final API Output Schema (LLM Recommendation) ---
# This schema models the structured output expected from the LLM,
# which the backend should serialize and return to the mobile app.
class AlertRecommendationSchema(Schema):
    """
    The structured recommendation output to be sent to the client.
    """
    # The calculated severity (e.g., 'High', 'Moderate')
    severity = fields.Str(required=True, validate=validate.OneOf(["High", "Moderate", "Low"]))
    # The primary recommendation message
    message = fields.Str(required=True)
    # A list of actionable steps for the user
    actions = fields.List(fields.Str(), required=True)
    # The source of the recommendation (e.g., 'Guardianly AI')
    source = fields.Str(required=True)

# --- Existing API Input Schema (from previous advice) ---
# This schema is used to validate the JSON input to the /api/generate_prompt endpoint.
class GeneratePromptRequestSchema(Schema):
    """
    The input data schema for the /api/generate_prompt endpoint.
    """
    hazard = fields.Str(required=True)
    user_lat = fields.Float(required=True)
    user_lng = fields.Float(required=True)