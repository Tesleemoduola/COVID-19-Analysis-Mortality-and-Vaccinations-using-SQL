--Inspect the coviddeaths table
Select *
From 
   coviddeaths
Where 
    continent is not null 

--Inspect the covidvaccinations table
Select *
From 
   covidvaccinations
Where 
   continent is not null

-- Select variables for the analysis
Select 
    location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
From 
    coviddeaths
Where 
    continent is not null 
order by 
    location,date;

-- And for vaccination
SELECT 
    location, 
    date, 
    total_vaccinations, 
    new_vaccinations, 
    people_vaccinated, 
    people_fully_vaccinated, 
    population_density
FROM 
    covidvaccinations
WHERE 
    continent IS NOT NULL
ORDER BY 
    location, date;

--ANALYSIS BY COUNTRIES
 
-- Total Cases vs Total Deaths (Shows likelihood of dying when contract covid in a country)
Select 
    location, 
	date, 
	total_cases,
	total_deaths, 
	(total_deaths/total_cases)*100 as DeathPercentage
From 
    coviddeaths
Where 
    continent is not null 
order by 
    total_cases, total_deaths

-- Total Cases vs Population (Percentage of population infected with Covid)
Select 
     location, 
	 date, 
	 Population, 
	 total_cases,  
	 (total_cases/population)*100 as PercentPopulationInfected
From 
    coviddeaths
order by population, PercentPopulationInfected

-- Countries with Highest Infection Rate compared to Population
SELECT 
    location, 
    Population, 
    MAX(total_cases) AS HighestInfectionCount, 
    ROUND((MAX(total_cases)::NUMERIC / Population::NUMERIC) * 100, 2) AS PercentPopulationInfected
FROM 
    coviddeaths
GROUP BY 
    Location, Population
ORDER BY 
    PercentPopulationInfected DESC;

--BREAK DOWN BY CONTINENTS

--Contintents with the highest death count per population
Select 
     continent, 
	 MAX(cast(Total_deaths as int)) as TotalDeathCount
From 
     coviddeaths
Where 
     continent is not null 
Group by 
     continent
order by 
     TotalDeathCount desc

-- Contintents with the highest vaccination per population
Select 
     continent, 
	 MAX(cast(total_vaccinations as BIGINT)) as TotalVaccination
From 
     covidvaccinations
Where 
     continent is not null 
Group by 
     continent
order by 
     Totalvaccination desc

-- GLOBAL NUMBERS

SELECT 
    SUM(new_cases) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths, 
    ROUND((SUM(CAST(new_deaths AS INT)) * 1.0 / SUM(new_cases)) * 100, 2) AS DeathPercentage
FROM 
    coviddeaths
WHERE 
    continent IS NOT NULL
ORDER BY 
    total_cases DESC, total_deaths DESC;

-- CALCULATIONS USING COMMON TABLE EXPRESSION (CTE)

-- Total Population vs Vaccinations. Percentage of Population with at least one vaccination
WITH VaccinationData AS (
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS FLOAT)) 
            OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated,
        ROUND(
            CAST(
                (SUM(CAST(vac.new_vaccinations AS FLOAT)) 
                OVER (PARTITION BY dea.location ORDER BY dea.date) / dea.population) * 100 
                AS NUMERIC
            ), 
            3
        ) AS PercentageVaccinated
    FROM 
        coviddeaths dea
    JOIN 
        covidvaccinations vac
    ON 
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
)
SELECT *
FROM VaccinationData
WHERE 
    new_vaccinations IS NOT NULL
    AND RollingPeopleVaccinated IS NOT NULL
    AND PercentageVaccinated IS NOT NULL
ORDER BY 
    location, date;

--Vaccination Trends Across Continents. Analyze vaccination progress to identify 
--trends and disparities accross continents and countries.
WITH VaccinationData AS (
    SELECT 
        dea.continent, 
        dea.date, 
        dea.population,
        vac.new_vaccinations,
        SUM(vac.new_vaccinations) 
            OVER (PARTITION BY dea.continent ORDER BY dea.date) / dea.population * 100 AS VaccinationRate
    FROM 
        coviddeaths dea
    JOIN 
        covidvaccinations vac
    ON 
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
),
MonthlyData AS (
    SELECT 
        continent, 
        DATE_TRUNC('month', date) AS Month, 
        SUM(new_vaccinations) AS TotalNewVaccinations,
        AVG(VaccinationRate) AS AvgVaccinationRate
    FROM 
        VaccinationData
    GROUP BY 
        continent, Month
)
SELECT 
    continent, 
    Month, 
    TotalNewVaccinations, 
    ROUND(AvgVaccinationRate::numeric, 2) AS AvgVaccinationRate
FROM 
    MonthlyData
WHERE
     AvgVaccinationRate IS not NULL
ORDER BY 
    Month, continent;

--Deaths vs Vaccination Rollout. Examine correlation between vaccination rollout & death rates.
WITH VaccinationData AS (
    SELECT 
        dea.continent, 
        dea.date, 
        dea.population,
        vac.new_vaccinations,
        SUM(vac.new_vaccinations) 
            OVER (PARTITION BY dea.continent ORDER BY dea.date) / dea.population * 100 AS VaccinationRate
    FROM 
        coviddeaths dea
    JOIN 
        covidvaccinations vac
    ON 
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
),
MonthlyData AS (
    SELECT 
        continent, 
        DATE_TRUNC('month', date) AS Month, 
        SUM(new_vaccinations) AS TotalNewVaccinations,
        AVG(VaccinationRate) AS AvgVaccinationRate
    FROM 
        VaccinationData
    GROUP BY 
        continent, Month
)
SELECT 
    continent, 
    Month, 
    TotalNewVaccinations, 
    ROUND(AVG(VaccinationRate)::numeric, 2) AS AvgVaccinationRate
FROM 
    MonthlyData
WHERE
    AvgVaccinationRate IS not NULL
ORDER BY 
    Month, continent;

--Countries with Lowest Vaccination Rates. Identify countries with low vaccination:population
WITH VaccinationData AS (
    SELECT 
        dea.location, 
        dea.population, 
        SUM(CAST(vac.new_vaccinations AS NUMERIC)) 
            OVER (PARTITION BY dea.location ORDER BY dea.date) / dea.population * 100 AS VaccinationRate
    FROM 
        coviddeaths dea
    JOIN 
        covidvaccinations vac
    ON 
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
)
SELECT 
    location, 
    population, 
    VaccinationRate
FROM 
    VaccinationData
ORDER BY 
    VaccinationRate ASC
LIMIT 10;

-- Cumulative Vaccination by Continents and Countries
WITH PopvsVac (Continent, location, Date, Population, New_Vaccinations, RollingPeopleVaccinated) AS
(
    SELECT 
        dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS INT)) 
            OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
    FROM 
        coviddeaths dea
    JOIN 
        covidvaccinations vac
    ON 
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
)
SELECT 
    *, 
    (RollingPeopleVaccinated / Population) * 100 AS PercentageVaccinated
FROM 
    PopvsVac
WHERE 
    New_Vaccinations IS NOT NULL
    AND RollingPeopleVaccinated IS NOT NULL
    AND (RollingPeopleVaccinated / Population) * 100 IS NOT NULL;

--FURTHER ANALYSIS

--Peak New Cases vs Healthcare Infrastructure
--Analyze countries with highest peak in new cases and healthcare capacity (e.g hospital beds).
SELECT 
    dea.location, 
    MAX(dea.new_cases) AS PeakNewCases, 
    dea.population, 
    dea.hospital_beds_per_thousand,
    (MAX(dea.new_cases) / dea.population) * 100 AS PeakInfectionRate
FROM 
    coviddeaths dea
WHERE 
    dea.continent IS NOT NULL
GROUP BY 
    dea.location, dea.population, dea.hospital_beds_per_thousand
ORDER BY 
    PeakNewCases;

--Continent-Level Vaccination to Death Ratio
--Assess how well continents are vaccinating relative to their death counts.
SELECT 
    dea.continent, 
    SUM(CAST(dea.new_deaths AS NUMERIC)) AS TotalDeaths,
    SUM(CAST(vac.new_vaccinations AS NUMERIC)) AS TotalVaccinations,
    (SUM(CAST(vac.new_vaccinations AS NUMERIC)) / SUM(CAST(dea.new_deaths AS NUMERIC))) AS VaccinationToDeathRatio
FROM 
    coviddeaths dea
JOIN 
    covidvaccinations vac
ON 
    dea.location = vac.location
    AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL
GROUP BY 
    dea.continent
ORDER BY 
    VaccinationToDeathRatio DESC;

--Timeline for Achieving Full Vaccination
--Estimate how long it will take countries to be fully vaccinated at current vaccination rates.
SELECT 
    dea.location, 
    dea.population, 
    AVG(vac.new_vaccinations) AS AvgDailyVaccinations,
    (dea.population - SUM(vac.new_vaccinations) 
        OVER (PARTITION BY dea.location ORDER BY dea.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) 
    / NULLIF(AVG(vac.new_vaccinations), 0) AS DaysToFullVaccination
FROM 
    coviddeaths dea
JOIN 
    covidvaccinations vac
ON 
    dea.location = vac.location
    AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL
GROUP BY 
    dea.location, dea.population
ORDER BY 
    DaysToFullVaccination ASC;

--Infection and Mortality Rates Comparison
--Compare infection and mortality rates across countries to identify outliers.
SELECT 
    dea.location, 
    (SUM(dea.total_cases) / dea.population) * 100 AS InfectionRate,
    (SUM(dea.total_deaths) / SUM(dea.total_cases)) * 100 AS MortalityRate
FROM 
    coviddeaths dea
WHERE 
    dea.continent IS NOT NULL
GROUP BY 
    dea.location, dea.population
ORDER BY 
    MortalityRate DESC, InfectionRate DESC;

--Disease profiles and COVID deaths
SELECT 
    cd.continent,
    cd.location,
    cd.date AS report_date,
    cd.cardiovasc_death_rate AS cardiovascular_death_rate,
    cd.diabetes_prevalence AS diabetes_prevalence,
    cd.total_deaths,
    cd.new_deaths,
    cd.new_deaths_per_million,
    cd.population_density,
    cd.life_expectancy,
    cd.median_age
FROM 
    coviddeaths cd
WHERE 
    cd.continent IS NOT NULL
ORDER BY 
    cd.continent, cd.location, cd.date;

--Analyze relationship between gender, smoking and Covid deaths
SELECT 
    cd.continent,
    cd.location,
    cd.date AS report_date,
    cd.female_smokers,
    cd.male_smokers,
    cd.total_deaths,
    cd.new_deaths,
    cd.new_deaths_per_million,
    cd.population,
    cd.median_age
FROM 
    coviddeaths cd
WHERE 
    cd.continent IS NOT NULL
ORDER BY 
    cd.continent, cd.location, cd.date;

--Analyze vaccination rate by gender
SELECT 
    cv.continent,
    cv.location,
    cv.date AS report_date,
    cv.female_smokers,
    cv.male_smokers,
    cv.total_vaccinations,
    cv.people_vaccinated,
    cv.people_fully_vaccinated,
    cv.total_boosters,
    cv.new_vaccinations,
    cv.total_vaccinations_per_hundred,
    cv.people_vaccinated_per_hundred,
    cv.people_fully_vaccinated_per_hundred
FROM 
    covidvaccinations cv
WHERE 
    cv.continent IS NOT NULL
ORDER BY 
    cv.continent, cv.location, cv.date;


-- CALCULATION USING TEMPORARY TABLE

-- Drop temporary table if it exists
DROP TABLE IF EXISTS PercentPopulationVaccinated;

-- Create a new temporary table
CREATE TEMP TABLE PercentPopulationVaccinated (
    Continent VARCHAR(255),
    Location VARCHAR(255),
    Date DATE,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

-- Insert data into the temporary table
INSERT INTO PercentPopulationVaccinated
SELECT 
    dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS NUMERIC)) 
        OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
FROM 
    coviddeaths dea
JOIN 
    covidvaccinations vac
ON 
    dea.location = vac.location
    AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;

Select *
From PercentPopulationVaccinated;

-- Retrieve data and calculate the percentage of the population vaccinated
SELECT 
    *, 
    (RollingPeopleVaccinated / Population) * 100 AS PercentageVaccinated
FROM 
    PercentPopulationVaccinated;

-- CREATE VIEW FOR FUTURE VISUALIZATION

CREATE VIEW PercentPopulationVaccinated AS
SELECT 
    dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS NUMERIC)) 
        OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated,
    (SUM(CAST(vac.new_vaccinations AS NUMERIC)) 
        OVER (PARTITION BY dea.location ORDER BY dea.date) / dea.population) * 100 AS PercentageVaccinated
FROM 
    coviddeaths dea
JOIN 
    covidvaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;

-- Retrieve View
SELECT * 
FROM PercentPopulationVaccinated;