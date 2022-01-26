using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace ABC.Asap.Dispatch.Web.Controllers;

[ApiController]
public class ErrorController : ControllerBase
{
    [Route("/error")]
    public IActionResult Error([FromServices] IWebHostEnvironment webHostEnvironment)
    {
        if (webHostEnvironment.IsDevelopment())
        {
            var context = HttpContext.Features.Get<IExceptionHandlerFeature>();
            return Problem(
                detail: context?.Error.ToString(),
                title: context?.Error.Message);
        }
        
        return Problem();
    }
}