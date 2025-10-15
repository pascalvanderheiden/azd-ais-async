# Copilot Instructions for azd-ais-async

## Architecture Overview
This project implements an **asynchronous integration pattern** that deploys onto an existing Azure Integration Services Landing Zone. The pattern demonstrates a microservices-like approach using Azure Logic Apps, Service Bus, and Cosmos DB for customer data processing.

### Key Components
- **Orchestration Workflow** (`orchestration-customer-wf`): HTTP-triggered Logic App that receives REST API calls and forwards messages to Service Bus
- **Processing Workflow** (`processing-customer-wf`): Service Bus-triggered Logic App that processes queued messages and performs CRUD operations on Cosmos DB
- **API Management**: Exposes the orchestration workflow via REST API with authentication and routing
- **Landing Zone Dependencies**: Connects to pre-existing shared services (VNet, Key Vault, Storage, App Service Plan)

### Data Flow
1. API Management receives HTTP requests and routes to Logic App orchestration workflow
2. Orchestration workflow composes Service Bus messages and queues them
3. Processing workflow is triggered by Service Bus messages and performs database operations
4. All communication uses managed identities and private endpoints for security

## Development Workflows

### Initial Setup
```bash
azd auth login
azd init -t pascalvanderheiden/azd-ais-async
azd up
```

The `azd up` command runs interactive scripts that discover and connect to existing Landing Zone resources (Service Bus, VNet, Key Vault, etc.).

### Testing
Use `tests.http` file with REST Client extension. Key variables to set:
- `@apimName`: API Management instance name
- `@frontDoorGwEndpoint`: Front Door endpoint (if using Front Door)
- `@subscriptionKeyConsumer`: API Management subscription key

### Deployment Lifecycle
1. **preprovision.ps1**: Interactive resource selection from Landing Zone
2. **predeploy.ps1**: Pre-deployment configuration
3. **postdeploy.ps1**: Post-deployment setup and API Management configuration

## Project-Specific Patterns

### Logic Apps Structure
- Located in `/workflow/` directory
- Each workflow has its own folder with `workflow.json`
- Use `workflow-designtime/` for development-time settings
- Stateless workflows for better performance and scaling

### API Management Integration
- OpenAPI definitions in `/infra/core/gateway/openapi/`
- Policy templates in `/infra/core/gateway/policies/` with placeholder replacement
- Policies handle authentication, routing, and parameter extraction
- Backend service configuration points to Logic Apps with SAS tokens

### Bicep Infrastructure Patterns
- **Resource Token**: `${abbrs.resourceType}${resourceToken}` for unique naming
- **Cross-Resource Group References**: Pattern deploys to new RG but references existing Landing Zone resources
- **Private DNS Zone Management**: Creates and links private DNS zones for private endpoints
- **Conditional Deployment**: Uses `deployToAse` parameter to handle ASE v3 vs standard App Service Plan deployment

### Schema Validation
JSON schemas in Logic Apps support nullable message objects using `"type": ["object", "null"]` pattern.

### Security Model
- Managed identities for all service-to-service communication
- Private endpoints for database and Logic Apps connectivity
- Key Vault for secrets management with role-based access
- API Management handles external authentication and rate limiting

## Critical Files
- `/azure.yaml`: AZD configuration with PowerShell hooks
- `/infra/main.bicep`: Main infrastructure template with Landing Zone integration
- `/workflow/*/workflow.json`: Logic App workflow definitions
- `/scripts/preprovision.ps1`: Interactive Landing Zone resource discovery
- `/infra/core/gateway/policies/api-policy.xml`: API Management policy template

## Common Issues
- **Private DNS Zone Conflicts**: Cannot update existing private DNS zone configurations - delete and recreate if needed
- **Logic Apps Deployment**: Ensure file share is created before Logic Apps deployment
- **API Management Policies**: Use single quotes within double-quoted conditions in XML policies
