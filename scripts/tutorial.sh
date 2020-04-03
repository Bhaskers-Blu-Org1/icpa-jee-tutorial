# Step 1
appsody init kabanero/java-openliberty

# Step 2
mkdir -p src/main/resources/META-INF
cat<<EOF > src/main/resources/META-INF/persistence.xml
<?xml version="1.0" encoding="UTF-8"?>
<persistence version="2.2"
    xmlns="http://xmlns.jcp.org/xml/ns/persistence"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/persistence
                        http://xmlns.jcp.org/xml/ns/persistence/persistence_2_2.xsd">
    <persistence-unit name="jee-sample" transaction-type="JTA">
        <jta-data-source>jdbc/sample</jta-data-source>
    </persistence-unit>
</persistence>
EOF

mkdir -p src/main/java/dev/appsody/jpa/dao
cat<<EOF > src/main/java/dev/appsody/jpa/dao/GenericDao.java
package dev.appsody.jpa.dao;

import java.util.List;

import javax.enterprise.context.Dependent;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;

@Dependent
public class GenericDao<T> {

    @PersistenceContext(name = "jee-sample")
    private EntityManager em;

    public void create(T resource) {
        em.persist(resource);
    }

    public T find(Class<T> clazz, String resourceId) {
        return em.find(clazz, resourceId);
    }

    public void updateDepartment(T resource) {
        em.merge(resource);
    }

    public void deleteDepartment(T resource) {
        em.remove(resource);
    }

    /**
     *
     * Assumes all JPA entities in this application have a
     * "findAll" named query.
     */
    public List<T> readAll(Class<T> clazz) {
        return em.createNamedQuery(clazz.getSimpleName() + ".findAll", clazz).getResultList();
    }
}
EOF

mkdir -p src/main/java/dev/appsody/jpa/model
cat<<EOF > src/main/java/dev/appsody/jpa/model/Department.java
package dev.appsody.jpa.model;

import java.io.Serializable;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.NamedQuery;

/**
 * The persistent class for the DEPARTMENT database table.
 */
@Entity
@NamedQuery(name="Department.findAll", query="SELECT d FROM Department d")
public class Department implements Serializable {
    private static final long serialVersionUID = 1L;
    private String deptno;
    private String deptname;
    private String location;

    public Department() {
    }

    public Department(String deptno, String deptname, String location) {
        super();
        this.deptno = deptno;
        this.deptname = deptname;
        this.location = location;
    }

    @Id
    public String getDeptno() {
        return this.deptno;
    }

    public void setDeptno(String deptno) {
        this.deptno = deptno;
    }

    public String getDeptname() {
        return this.deptname;
    }

    public void setDeptname(String deptname) {
        this.deptname = deptname;
    }

    public String getLocation() {
        return this.location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

}
EOF


mkdir -p src/main/java/dev/appsody/jpa/resources
cat<<EOF > src/main/java/dev/appsody/jpa/resources/DepartmentResource.java
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
EOF

mkdir -p src/main/java/dev/appsody/starter
cat<< EOF > src/main/java/dev/appsody/starter/DatabaseResource.java
package dev.appsody.starter;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.SQLException;
import java.text.MessageFormat;

import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.sql.DataSource;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("/database")
public class DatabaseResource {

    private static final String JDBC_JNDI_CONTEXT = "jdbc/sample";

    /**
     * REST endpoint for internal database metadata for the application connection.
     */
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public JsonObject databaseMetadata() {

        try {
            DataSource ds = InitialContext.doLookup(JDBC_JNDI_CONTEXT);

            JsonObjectBuilder response = buildConnectionMetadataResponse(ds);
            return response.build();
        } catch (NamingException e) {
            String errMsg = MessageFormat.format("Unable to locate connection pool in [{0}] due to {1}",
                    JDBC_JNDI_CONTEXT, e.getMessage());
            throw new RuntimeException(errMsg, e);
        }
    }

    /**
     * Builds a JSON array with the database metadata.
     */
    private JsonObjectBuilder buildConnectionMetadataResponse(DataSource ds) {
        JsonObjectBuilder builder = Json.createObjectBuilder();

        try (Connection dbConn = ds.getConnection()) {
            dbConn.getClientInfo().entrySet().stream()
                    .sorted((e1, e2) -> ((String) e1.getKey()).compareTo((String) e2.getValue()))
                    .forEach(entry -> builder.add("client.info." + (String) entry.getKey(), (String) entry.getValue()));
            DatabaseMetaData metaData = dbConn.getMetaData();
            builder.add("db.product.name", metaData.getDatabaseProductName());
            builder.add("db.product.version", metaData.getDatabaseProductVersion());
            builder.add("db.major.version", metaData.getDatabaseMajorVersion());
            builder.add("db.minor.version", metaData.getDatabaseMinorVersion());
            builder.add("db.driver.version", metaData.getDriverVersion());
            builder.add("db.jdbc.major.version", metaData.getJDBCMajorVersion());
            builder.add("db.jdbc.minor.version", metaData.getJDBCMinorVersion());
        } catch (SQLException e) {
            String errMsg = MessageFormat
                    .format("Unable to obtain connection metadata from connection pool retrived from "
                            + "context [{0}] due to {1}", JDBC_JNDI_CONTEXT, e.getMessage());
            throw new RuntimeException(errMsg, e);
        }
        return builder;
    }

}
EOF


# step 7

cat .db2.temp.env | sed "s/db=/db_database=/" | sed "s/host=/db_server=/" | sed "s/port=/db_port=/" | sed     "s/username=/db_user=/" | sed "s/password=/db_password=/" | grep db_ > .db2.appsody.run.env
