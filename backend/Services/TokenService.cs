using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using EduQuest.Api.Models;
using Microsoft.IdentityModel.Tokens;
namespace EduQuest.Api.Services;
public class TokenService(IConfiguration config) {
 public string Create(AppUser user) {
  var claims = new[] { new Claim(ClaimTypes.NameIdentifier,user.Id.ToString()), new Claim(ClaimTypes.Name,user.Name), new Claim(ClaimTypes.Email,user.Email), new Claim(ClaimTypes.Role,user.Role) };
  var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!));
  var token = new JwtSecurityToken(config["Jwt:Issuer"],config["Jwt:Audience"],claims,expires:DateTime.UtcNow.AddDays(7),signingCredentials:new SigningCredentials(key,SecurityAlgorithms.HmacSha256));
  return new JwtSecurityTokenHandler().WriteToken(token);
 }
}
