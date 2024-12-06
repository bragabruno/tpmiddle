# Source Code Directory

This directory contains all the source code for the application, organized according to Clean Architecture principles.

## Directory Structure

- `application/` - Application layer (Controllers, Services, Interfaces)
- `domain/` - Business logic and domain models
- `infrastructure/` - External interfaces and implementations
- `presentation/` - UI and presentation layer
- `utils/` - Utility functions and helpers

## Guidelines

1. Follow the dependency rule: dependencies should only point inward
2. Keep the domain layer independent of external concerns
3. Use interfaces to define boundaries between layers
4. Implement SOLID principles throughout the codebase

## Layer Responsibilities

### Application Layer
- Orchestrates the flow of data and business rules
- Contains use cases and application-specific business rules
- Depends on domain layer, but is independent of infrastructure

### Domain Layer
- Contains enterprise-wide business rules and entities
- Pure business logic with no external dependencies
- Includes interfaces that are implemented by outer layers

### Infrastructure Layer
- Implements interfaces defined in domain layer
- Handles external concerns (databases, web services, etc.)
- Contains all framework and driver code

### Presentation Layer
- Handles UI concerns and user interaction
- Implements view-specific logic and formatting
- Depends on application layer for business operations

### Utils
- Contains shared utilities and helper functions
- Framework-independent tools and extensions
- Common constants and type definitions
