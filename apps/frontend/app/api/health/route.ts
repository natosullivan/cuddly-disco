export async function GET() {
  return Response.json(
    { status: 'healthy', service: 'cuddly-disco-frontend' },
    { status: 200 }
  )
}
