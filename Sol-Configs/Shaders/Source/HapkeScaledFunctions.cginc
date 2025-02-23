// Double-lobed Henyey-Greenstein function (6.7a)
float PI_HG2(float g, float b, float c)
{
    float backwardLobe = ((1.0+c)/2.0) * ((1-b*b) /  pow(1.0-2.0*b*cos(g)+b*b, 1.5));
    float forwardLobe =  ((1.0-c)/2.0) * ((1-b*b) /  pow(1.0+2.0*b*cos(g)+b*b, 1.5));
    return backwardLobe + forwardLobe;
}
// Shadow Hiding Opposition function (9.22)
float B_s(float g, float h_s)
{
    return 1.0/(1.0+(1.0/h_s)*tan(g/2.0));
}
// (9.43)
float B_c(float g, float h_c, float K)
{
    return 1.0 / (1.0 + (1.3 + K)*(1.0/h_c * tan(g/2.0) + pow(1.0/h_c * tan(g/2.0), 2.0)));
}
// Albedo Factor: (8.22b)
float gamma(float w)
{
    return sqrt(1.0-w);
}
// Diffusive Reflectance: (8.25)
float r_0(float w)
{
    return 2.0 / (1.0 +  gamma(w));
}
// Ambartsumian–Chandrasekhar H function: (8.56)
float H_Func(float x, float w)
{
    float value = 1.0/(1.0 - w * x * (r_0(w) + (1.0-2.0*r_0(w)*x)/2.0 * log((1.0+x)/x)));
    return value;
}
// (12.45b)
// Verified
float E_1(float x, float theta)
{
    return exp(-1.0*(2.0/3.14159)*(1.0/tan(theta))*(1.0/tan(x)));
    
}
// (12.45c)
float E_2(float x, float theta)
{
    return exp( -1.0 * (1.0/3.14159) * pow(1.0/tan(theta), 2.0) * pow(1.0/tan(x), 2.0)); 
}
// (12.45a)
float X(float theta)
{
    return 1.0 /sqrt(1.0 + 3.14159*pow(tan(theta), 2.0));
}
// (12.48)
float n_e(float x, float theta)
{
    return X(theta)*(cos(x)+sin(x)*tan(theta) * (E_2(x, theta) / (2.0 - E_1(x, theta))));
}
// (12.51)
float f(float psi)
{
    return exp(-2.0 * tan(psi/2.0));
}
// Section (12.2.2 - 12.2.3)
float S(float mu_0, float mu, float psi, float theta)
{
    float i = acos(mu_0);
    float e = acos(mu);
    if (e > i)
    {
        // (12.47)
        // Verified
        float mu_e = X(theta) * (cos(e) + sin(e)*tan(theta) * (E_2(e, theta) - pow(sin(psi/2.0), 2.0) * E_2(i, theta)) / (2.0 - E_1(e, theta) - (psi / 3.14159) * E_1(i, theta)));
        
        // (12.50)
        // Verified        
        return ((mu_e/n_e(e, theta))  * (mu_0 / n_e(i, theta)) * (X(theta) / (1.0 - f(psi) + f(psi)*X(theta) * (mu_0 / n_e(i, theta)))));
    }
    else
    {
        // (12.53)
        // Verified
        float mu_e = X(theta) * (cos(e) + sin(e)*tan(theta) * (cos(psi) * E_2(i, theta) + pow(sin(psi/2.0), 2.0) * E_2(e, theta)) / (2.0 - E_1(i, theta) - (psi / 3.14159) * E_1(e, theta)));

        // (12.54)
        // Verified
        return ((mu_e/n_e(e, theta))  * (mu_0 / n_e(i, theta)) * (X(theta) / (1.0 - f(psi) + f(psi)*X(theta) * (mu / n_e(e, theta)))));
    }
}

float3 CalculateHapkeLighting(float4 col, float3 worldNormal, float3 viewDir, float shadow, float3 lightDir,
                              float _Blend, float _GammaBoost, float _LightBoost, float _porosityCoeffient, float _Theta, float4 scatterData, float4 surgeData)
{
	// Main light
    float NdotL = saturate(dot(worldNormal, lightDir)) * shadow;
    NdotL = pow(NdotL, _Hapke);
    float3 H = normalize(lightDir + viewDir);
    float NdotH = saturate(dot(worldNormal, H));

    float mu_0 = clamp(dot(lightDir,worldNormal),0.0001,1);
    float mu = clamp(dot(viewDir,worldNormal),0.0001,1);
    float g = clamp(acos(dot(lightDir,viewDir)), 0, 3.14159);

    float w = scatterData.r;
    float b = scatterData.g;
    float c = 2*(scatterData.b)-1;

    float b_s0 = 2*(surgeData.r);
    float h_s = surgeData.g;
    float b_c0 = 2*(surgeData.b);
    float h_c = (surgeData.a);

    float theta = (_Theta * 3.14159)/180;
    
	// Fresnel reflections
    GET_REFLECTION_COLOR
    GET_REFRACTION_COLOR
    float fresnel = FresnelEffect(worldNormal, viewDir, _FresnelPower);

    float spec = pow(NdotH, _SpecularPower) * _LightColor0.rgb * _SpecularIntensity * col.a * shadow;

    float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * col.rgb;
    float3 diffuse = _LightColor0.rgb * GammaToLinearSpace(col.rgb);
    float3 specular = spec * _LightColor0.rgb;
    float3 reflection = fresnel * reflColor * col.a * _EnvironmentMapFactor; // For refraction
    float3 refraction = (1 - fresnel) * refrColor * _RefractionIntensity;
    //reflection *= shadow + UNITY_LIGHTMODEL_AMBIENT;

    float lighting = ((_Blend)*(mu_0 / (mu_0+mu)) + (1-_Blend)*(mu_0)) * shadow;
    float3 reflectance = (diffuse/4) * (_porosityCoeffient * (lighting) * (PI_HG2(g, b, c)*(1+b_s0*B_s(g, h_s))+(H_Func(mu_0/_porosityCoeffient, w)*H_Func(mu/_porosityCoeffient, w)-1)) * (1+b_c0*B_c(g, h_c, _porosityCoeffient)) * S(mu_0, mu, g, theta));
    reflectance = pow(reflectance, _GammaBoost);
    reflectance *= _LightBoost;

    float3 scattering = 0;
    
    return LinearToGammaSpace(reflectance) + ambient + specular + reflection + refraction * NdotL + scattering;
}