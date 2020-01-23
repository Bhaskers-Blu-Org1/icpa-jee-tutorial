package dev.appsody.jpa.resources;

import javax.enterprise.context.RequestScoped;
import javax.inject.Inject;
import javax.json.Json;
import javax.json.JsonArray;
import javax.json.JsonArrayBuilder;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;
import javax.transaction.Transactional;
import javax.ws.rs.Consumes;
import javax.ws.rs.DELETE;
import javax.ws.rs.FormParam;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import dev.appsody.jpa.dao.GenericDao;
import dev.appsody.jpa.model.Department;

@RequestScoped
@Path("departments")
public class DepartmentResource {

	@Inject
	private GenericDao<Department> dao;

	/**
	 * Creates a new dept from the submitted data (name, time and
	 * location) by the user.
	 */
	@POST
	@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
	@Transactional
	public Response addNewDepartment(@FormParam("name") String name, @FormParam("deptno") String deptno,
			@FormParam("location") String location) {
		Department newDepartment = new Department(name, deptno, location);
		if (dao.find(Department.class, deptno) != null) {
			return Response.status(Response.Status.BAD_REQUEST).entity("Department already exists").build();
		}
		dao.create(newDepartment);
		return Response.status(Response.Status.NO_CONTENT).build();
	}

	/**
	 * Updates a dept with the submitted data (name, deptno and
	 * location) by the user.
	 */
	@PUT
	@Path("{deptno}")
	@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
	@Transactional
	public Response updateDepartment(@FormParam("name") String name, @PathParam("deptno") String deptno,
			@FormParam("location") String location) {
		Department prevDepartment = dao.find(Department.class, deptno);
		if (prevDepartment == null) {
			return Response.status(Response.Status.NOT_FOUND).entity("Department does not exist").build();
		}
		prevDepartment.setDeptname(name);
		prevDepartment.setLocation(location);

		dao.updateDepartment(prevDepartment);
		return Response.status(Response.Status.NO_CONTENT).build();
	}

	/**
	 * Deletes a specific existing/stored dept
	 */
	@DELETE
	@Path("{deptno}")
	@Transactional
	public Response deleteDepartment(@PathParam("deptno") String deptNo) {
		Department dept = dao.find(Department.class, deptNo);
		if (dept == null) {
			return Response.status(Response.Status.NOT_FOUND).entity("Department does not exist").build();
		}
		dao.deleteDepartment(dept);
		return Response.status(Response.Status.NO_CONTENT).build();
	}

	/**
	 * Returns a specific existing/stored dept
	 */
	@GET
	@Path("{deptno}")
	@Produces(MediaType.APPLICATION_JSON)
	@Transactional
	public JsonObject getDepartment(@PathParam("deptno") String deptNo) {
		JsonObjectBuilder builder = Json.createObjectBuilder();
		Department dept = dao.find(Department.class, deptNo);
		if (dept != null) {
			builderAddDepartment(builder, dept);
		}
		return builder.build();
	}

	/**
	 * Returns all existing/stored depts
	 */
	@GET
	@Produces(MediaType.APPLICATION_JSON)
	@Transactional
	public JsonArray getDepartments() {
		JsonObjectBuilder builder = Json.createObjectBuilder();
		JsonArrayBuilder finalArray = Json.createArrayBuilder();
		for (Department dept : dao.readAll(Department.class)) {
			builderAddDepartment(builder, dept);
			finalArray.add(builder.build());
		}
		return finalArray.build();
	}

	/**
	 * Creates the JSON object for a department.
	 */
	private void builderAddDepartment(JsonObjectBuilder builder, Department dept) {
		builderAddIfNotNull(builder, dept.getDeptno(), "deptNo");
		builderAddIfNotNull(builder, dept.getDeptname(), "name");
		builderAddIfNotNull(builder, dept.getLocation(), "location");
	}

	/**
	 * Creates a fragment of the JSON object.
	 */
	private void builderAddIfNotNull(JsonObjectBuilder builder, String v, String n) {
		if (v != null) {
			builder.add(n, v);
		}
	}
}
